/*
 * GUI GUSTOMETRO
 * Francesco Pudda A.A. 2018/2019
 *
 * Utilizzo:
 *  Questo programma è composto da una GUI molto basilare, in cui si possono
 *  inserire i parametri per regolare il funzionamento del firmware del
 *  gustometro e dei pulsanti per pilotarlo.
 *  Al clic dei bottoni viene inviata sulla seriale una stringa con una
 *  struttura spiegata nella documentazione del firmware. I pulsanti devono
 *  essere non devono essere tenuti premuti, tranne il pulsante "Gira" che deve
 *  esserlo per tutto il tempo in cui si voglia mantenere il motore attivo.
 *  I pulsanti "Imposta posizione zero" e "Interrompi" non inviano parametri perché
 *  non ce ne è bisogno, mentre gli altri inviano sempre tutti i parametri
 *  anche se non ne usano qualcuno. Questo è stato fatto per ridurre il numero di
 *  variabili e condizioni da gestire.
 *  I parametri sono tutti di tipo intero, non usare decimali o verrà
 *  sollevato un errore. Le caselle di testo "Velocità di flusso" e "Volume"
 *  possono avere valori decimali ma servono per avere immediatamente i valori
 *  convertiti; ciò che viene inviato sulla seriale è il valore della casella
 *  "Velocità angolare" arrotondato.
 *  
 *
 *  N.B. Per la spiegazione in dettaglio delle modalità rifarsi alla
 *  documentazione del firmware.
 *
 * Libreria:
 *  La libreria grafica usata per la GUI è G4P ed è stata costruita tramite 
 *  il tool G4P GUI Builder. I commenti generati automaticamente da tale
 *  tool non sono stati rimossi
 */


import g4p_controls.*;
import processing.serial.*;
import java.util.*;

/*
 * Definisco le costanti e le variabili globali.
 * Le prime due sono la dimensione dei pacchetti della
 * calibrazione e il baudrate impiegato, la terza
 * è il coefficiente di conversione da velocità angolare
 * a flusso, e le restanti sono utilizzate per la routine
 * di calibrazione. In particolare sono state scritte come
 * costanti piuttosto che come altre variabili inseribili
 * dalla GUI per non appesantirla visto l'elevato numero
 * di caselle.
 */
final byte CALIBRATION_BUFFER_SIZE = 6; // byte
final byte FEEDBACK_BUFFER_SIZE = 2; // byte
final int BAUDRATE = 1000000; // baud/s
final float OMEGA_FLUX_COEFFICIENT = 2.715467f; // step/ul
final short ROUTINE_INCREMENT = 100; // ms e ul
final short ROUTINE_MINIMUM = 100; // ms e ul
final short ROUTINE_MAXIMUM = 1000; // ms e ul
final int SYRINGE_VOLUME = 55000; // ul
final short MAXIMUM_SPEED = 1200; // step/s

Serial port;
PrintWriter graph;
byte[] bufferRX = new byte[CALIBRATION_BUFFER_SIZE];
byte[] feedback = new byte[FEEDBACK_BUFFER_SIZE];

/* Alcune variabili globali */
int totalPulses;
boolean calibrationMode = false;
boolean calibrationRoutine = false;
int calibrationVolume = 0;
 
public void setup()
{
  size(470, 350, JAVA2D);
  createGUI();
  customGUI();
  
  /*
   * Inizializzo l'oggetto della seriale con un baudrate molto elevato
   * perché in caso di scrittura dei file di campionamento è necesaria
   * molta banda.
   * Indico inoltre fino a quale char è necessario porre i byte nel buffer
   * prima di chiamare serialEvent.
   */
  port = new Serial(this, Serial.list()[0], BAUDRATE);
  //port.buffer(CALIBRATION_BUFFER_SIZE);
  
  // Imposto la codifica britannica altrimenti String.format
  // scrive i decimali con la virgola che non possono essere
  // riconvertiti in float senza l'uso di altri oggetti.
  Locale.setDefault(new Locale("en", "UK"));
}

public void draw()
{
  background(230);
}

/*
 * Per gestire più byte al millisecondo è stato necessario
 * l'utilizzo della funzione serialEvent invece di gestire i byte
 * in ingresso dalla funzione draw (analoga di loop di arduino).
 * Processing carica un numero di byte in ingresso in un buffer
 * specificato dalla funzione buffer, dopo il quale viene chiamata
 * serialEvent.
 * I byte vengono letti e riconvertiti nel valore intero e poi scritti
 * su un file per mezzo del metodo di classe toUnsignedString poiché
 * in Java i primitivi sono tutti di tipo signed.
 */
void serialEvent(Serial port)
{
  /* Controllo se sono in modalità calibrazione o protocollo
   * per sapere quanti byte devo leggere ogni volta.
   */
  if (calibrationMode)
  {
    bufferRX = port.readBytes();
    
    /* 
     * Chiude il file se riceve un array con tutti elementi pari
     * a 0xff. Qui viene indicato -1 perché in java non esistono
     * primitive unsigned (tacci loro). Estraggo inoltre le informazioni
     * sulla lettura analogica e digitale che erano state inglobate in
     * un unico byte.
     */
    if ((bufferRX[4] != -1) || (bufferRX[5] != -1))
    {
      // Converto ed estraggo la maschera se presente
      int currTime = (bufferRX[0] & 0xff) << 24 | (bufferRX[1] & 0xff) << 16 | (bufferRX[2] & 0xff) << 8 | bufferRX[3] & 0xff;
      int motor = (bufferRX[4] & 0x80) / 0x80;
      int board = ((bufferRX[4] - (bufferRX[4] & 0x80)) & 0xff) << 8 | bufferRX[5] & 0xff;
      
      // Scrivo su file
      graph.println(String.format("%s\t%s\t%s", Integer.toUnsignedString(currTime), Integer.toUnsignedString(board), Integer.toUnsignedString(motor*1023)));
    }
    else
    {
      // Attendo la scrittura su file di eventuali stringhe
      // rimanenti e chiude il file
      graph.flush();
      graph.close();
      println("File chiuso");
      
      // Se si è dentro la routine di calibrazione, quando
      // chiude un file si chiama la funzione che controlla
      // se ne va aperto un altro subito dopo
      if (calibrationRoutine)
      {
        delay(1000);
        startCalibration();
      }
    }
  }
  else
  {
    feedback = port.readBytes();
    
    int currentIndex = (feedback[0] & 0xff) << 8 | feedback[1] & 0xff;
    
    println(String.format("%s/%s", Integer.toUnsignedString(currentIndex),
      Integer.toUnsignedString(totalPulses)));
  }
}

// Use this method to add additional statements
// to customise the GUI controls
public void customGUI()
{
  bt_run.fireAllEvents(true);
  tf_calibrationFile.setText(sketchPath(""));
}

/*
 * La routine di calibrazione funziona in questo modo.
 * Al click del bottone viene controllato se la casella
 * di routine è spuntata e in caso negativo si procede
 * con la normale calibrazione singola altrimenti si 
 * porta a vero la variabile calibrationRoutine, si
 * si inzia con la prima utilizzando i parametri nella
 * GUI, e poi ogni volta che viene chiuso un file viene
 * chiamata questa funzione. Questa incrementa i valori
 * di durata e volume secondo i criteri definiti dalle
 * costanti globali. Controlla inoltre il volume emesso
 * e ne tiene traccia fermando il loop quando
 * l'acquisizione successiva supererebbe il massimo della
 * siringa.
 */
public void startCalibration()
{
  // Incremento i valori e controllo i valori massimi
  int duration = Integer.parseInt(tf_pulseDuration.getText());
  float volume = Float.parseFloat(tf_pulseVolume.getText());
  volume += ROUTINE_INCREMENT;
  if (volume > ROUTINE_MAXIMUM)
  {
    volume = ROUTINE_MINIMUM;
    duration += ROUTINE_INCREMENT;
    if (duration > ROUTINE_MAXIMUM)
    {
      calibrationRoutine = false;
      calibrationVolume = 0;
      return;
    }
  }
  
  // Cambio le caselle di testo
  tf_pulseDuration.setText(Integer.toString(duration));
  tf_pulseDuration_change(tf_pulseDuration, GEvent.CHANGED);
  tf_pulseVolume.setText(String.format("%.2f", volume));
  tf_pulseVolume_change(tf_pulseVolume, GEvent.CHANGED);

  // Controllo il volume rimasto della siringa
  calibrationVolume += volume * Integer.parseInt(tf_pulsesForCalibration.getText());
  if (calibrationVolume >= SYRINGE_VOLUME)
  {
    println("Massimo volume raggiunto");
    calibrationRoutine = false;
    calibrationVolume = 0;
    return;
  }
  
  // Inizio nuova acquisizione
  String params = getParameters();
  String path = tf_calibrationFile.getText();
  graph = createWriter(String.format("%s/graph_%d%d_%d%d_%d.txt", path, 
    day(), month(), hour(), minute(), second()));
  String firstLine = String.format("Volume: %s,   Durata: %s,   Impulsi: %s,   Intervallo: %s",
    tf_pulseVolume.getText(), tf_pulseDuration.getText(), tf_pulsesForCalibration.getText(), tf_calibrationInterval.getText());
  graph.println(firstLine);
  
  port.write("D\n" + dl_activeChannel.getSelectedIndex() + "\n" + params);
}

/*
 * Funzione di processing che prima apre una finestra
 * per selezionare cartelle, e poi viene lanciata la
 * funzione con quella cartella come argomento della
 */
public void folderSelected(File selection)
{
  tf_calibrationFile.setText(selection.getAbsolutePath());
}

/*
 * Funzione che legge ed invia i parametri nell'ordine in cui si aspetta
 * il firmware del gustometro. Controlla inoltre se sono valori validi.
 */
public String getParameters()
{
  // Istruzione try...catch per verificare che i parametri siano tutti nel
  // formato corretto. Devono essere tutti int tranne omega che può essere
  // float ma viene arrotondato comunque
  try
  {
    int omega = (int) round(abs(Float.parseFloat(tf_omega.getText())));
    int direction = (-Boolean.compare(cb_direction.isSelected(),true) * 2) - 1;
    int pulseDuration = Integer.parseInt(tf_pulseDuration.getText());
    int neutralPulses = Integer.parseInt(tf_neutralPulses.getText());
    int tastantPulses = Integer.parseInt(tf_tastantPulses.getText());
    int tastantBlocks = Integer.parseInt(tf_tastantBlocks.getText());
    int pulsesToDiscard =  Integer.parseInt(tf_pulsesToDiscard.getText());
    int pulsesForCalibration = Integer.parseInt(tf_pulsesForCalibration.getText());
    int calibrationInterval = Integer.parseInt(tf_calibrationInterval.getText());   
    int triggerLength = Integer.parseInt(tf_triggerLength.getText());
    
    int nMotors = dl_nChannels.getSelectedIndex();
    /* Immagazzino il numero di impulsi totali da fare in modalità protocollo */
    totalPulses = 5 + neutralPulses * tastantBlocks * nMotors + 
      tastantPulses * tastantBlocks * nMotors;
    
    // Avvertimento in caso si imposti una velocità troppo elevata
    // La velocità verrà poi riportata al valore massimo lato dalla
    // libreria lato Arduino (si potrebbe anche cambiare da qui, è uguale)
    if (omega > MAXIMUM_SPEED)
    {
      println("Velocità angolare impostata superiore della massima consentita (1200 step/s)");
    }
    
    return String.valueOf(omega) + "," + String.valueOf(direction) + "," +
      String.valueOf(pulseDuration) + "," + String.valueOf(neutralPulses) + "," +
      String.valueOf(tastantPulses) + "," + String.valueOf(tastantBlocks) + "," +
      String.valueOf(pulsesToDiscard) + "," + String.valueOf(pulsesForCalibration) + "," +
      String.valueOf(calibrationInterval) + "," + String.valueOf(triggerLength)  + ",\n";
  }
  catch (NumberFormatException e)
  {
    println("Formato parametri sbagliato");
    return "";
  }
}
