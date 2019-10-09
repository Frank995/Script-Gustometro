
// DA IMPLEMENTARE TIMING JITTERATO


/*
 * FIRMWARE GUSTOMETRO
 * Francesco Pudda A.A. 2018/2019
 * 
 * Utilizzo:
 *  Questo firmware è formato da un loop principale che rimane
 *  in attesa di comandi dalla seriale. A seconda dei comandi
 *  ricevuti vengono eseguite modalità diverse.
 *  La struttura del comando è sempre uguale:
 *  X\nI\nP0,P0,...,P9,\n
 *  In cui X è una lettera che indica la modalità. I l'indice
 *  del motore utilizzato e P i vari parametri della modalità.
 *  Il comando viene ricevuto sotto forma di stringa che viene
 *  decomposta in base a questa suddivisione. C'è un piccolo
 *  ritardo tra l'invio del comando e l'effettiva esecuzione a
 *  causa del tempo di ricezione e delle operazioni sulla stringa.
 * 
 * X:
 *  R: modalità continua; parametri - motore, P0, P1, P9
 *  Z: ritorno a posizione iniziale; parametri - motore, P0, P9
 *  0: imposta posizione corrente come iniziale; parametri - motore
 *  D: calcolo ritardo; parametri - motore, P0, P2, P7, P8, P9
 *  P0: esegui protocollo con 1 motore (0 gusti, per debug); parametri - motore, P0, P1, P2, P9
 *  P1: esegui protocollo con 2 motori (1 gusto); parametri - motore, P0, P2, P3, P4, P5, P6, P9
 *  P2: esegui protocollo con 3 motori (2 gusti); parametri - P0, P2, P3, P4, P5, P6, P9
 *  S: interrompi ogni attività; nessun parametro
 *  W: mette in attesa o riprende l'attività: nessun parametro
 * 
 * I:
 *  0: neutro
 *  1: gusto 1
 *  2: gusto 2
 * 
 * P:
 *  P0: velocità angolare (intera, step/s)
 *  P1: direzione di rotazione (1 avanti, -1 indietro)
 *  P2: durata dell'impulso (ms)
 *  P3: numero di impulsi di neutro per blocco
 *  P4: numero di impulsi di gusto per blocco
 *  P5: numero di blocchi di gusto
 *  P6: impulsi da scartare nell'acquisizione per ripulire
 *  P7: numero impulsi per calibrazione
 *  P8: intervallo tra impulsi per calibrazione
 *  P9: durata del tempo ON del trigger (us)
 */

// Importo libreria e definisco costanti e variabili globali
#include <AccelStepper.h>

// Pin dei motori
#define DIRECTION_MOTOR1 2
  #define STEP_MOTOR1 3
#define DIRECTION_MOTOR2 4
  #define STEP_MOTOR2 5
#define DIRECTION_MOTOR3 6
  #define STEP_MOTOR3 7

// Indici dei parametri
#define MAX_PARAMS 10
  #define P_OMEGA 0 // step/s
  #define P_DIRECTION 1
  #define P_PULSE_DURATION 2 // ms
  #define P_NEUTRAL_PULSES 3
  #define P_TASTANT_PULSES 4
  #define P_TASTANT_BLOCKS 5
  #define P_PULSES_TO_DISCARD 6
  #define P_PULSES_FOR_CALIBRATION 7
  #define P_INTERVAL_BETWEEN_PULSES 8 // ms
  #define P_TRIGGER_LENGTH 9 // us

// Costanti per la comunicazione al PC
#define BAUDRATE 1000000 // baud/s
#define MOTOR_SAMPLING_PIN A3
#define PLATE_SAMPLING_PIN A5
#define SAMPLING_TIME 500 // us
#define PACKET_SIZE 6 // byte

// Velocità massima del motore
#define MAX_SPEED 5000 // step/s

// Costanti per l'indice dello stimolo e i pin usati
#define TTL_D 0
#define TTL_N 1
#define TTL_G1 2
#define TTL_G2 3
#define TTL_LSB_PIN 9
#define TTL_MSB_PIN 10
#define TTL_LENGTH 50 // ms
#define ISI 2000 // ms
#define ISI_JITTER 300 // ms 
#define STARTING_PULSES 5

// Array delle classi dei motori, più comodo rispetto a
// tre oggetti separati perché posso accedervi usando l'indice
// che arriva da Processing invece di un'istruzione if/else
AccelStepper steppersArray[] = {  AccelStepper(AccelStepper::DRIVER, STEP_MOTOR1, DIRECTION_MOTOR1),
                                  AccelStepper(AccelStepper::DRIVER, STEP_MOTOR2, DIRECTION_MOTOR2),
                                  AccelStepper(AccelStepper::DRIVER, STEP_MOTOR3, DIRECTION_MOTOR3) };

// Array dei parametri
long parameters[MAX_PARAMS];

// Stringa comando
String command;

// Array di byte da inviare
byte bufferTX[PACKET_SIZE];

void setup()
{
  // Imposto un baudrate molto alto per evitare
  // errori sulla seriale durante la calibrazione
  Serial.begin(BAUDRATE);

  // La velocità massima va impostata per prima
  // Ne imposto una ragionevolmente elevata
  steppersArray[0].setMaxSpeed(MAX_SPEED);
  steppersArray[1].setMaxSpeed(MAX_SPEED);
  steppersArray[2].setMaxSpeed(MAX_SPEED);

  // Imposto le modalità dei vari pin
  pinMode(DIRECTION_MOTOR1,OUTPUT); 
  pinMode(STEP_MOTOR1,OUTPUT);
  pinMode(DIRECTION_MOTOR2,OUTPUT); 
  pinMode(STEP_MOTOR2,OUTPUT);
  pinMode(DIRECTION_MOTOR3,OUTPUT); 
  pinMode(STEP_MOTOR3,OUTPUT);

  pinMode(PLATE_SAMPLING_PIN,INPUT);
  pinMode(MOTOR_SAMPLING_PIN,INPUT);
  
  pinMode(TTL_LSB_PIN,OUTPUT);
  pinMode(TTL_MSB_PIN,OUTPUT);
}

void loop()
{
  // Se non ci sono dati sulla seriale non esegue alcuna
  // operazione e rimane in attesa
  if (Serial.available() > 0)
  {    
    // Leggo la stringa in entrata
    command = Serial.readString();

    /*
     * Quando ho ricevuto dati inizio a decomporre la stringa.
     * Prendo l'indice del caratter \n, quindi mi ricavo la
     * sotto stringa dall'indice 0 a quello ricavato, e poi 
     * taglio la stringa fino a \n, tutto per tre volte
     * Invece di un ciclo for ho preferito farlo a mano così
     * registro modalità, motore e parametri in variabili
     * diverse.
     */
    String mode = command.substring(0,command.indexOf("\n"));
    command = command.substring(command.indexOf("\n") + 1);
    
    String motor = command.substring(0,command.indexOf("\n"));
    command = command.substring(command.indexOf("\n") + 1);
    
    String params = command.substring(0,command.indexOf("\n"));
    command = command.substring(command.indexOf("\n") + 1);

    // Prendo l'indice del motore come intero
    int motor_ind = motor.toInt();

    // Scrivo la stringa di parametri in un array.
    // La funzione si aspetta dei puntatori.
    // Vedere documentazione della funzione.
    readModeParameters(&params, parameters, MAX_PARAMS);

    // Calcolo il numero di step per la posizione bersaglio
    // Utilizzato per le modalità P0, P1 e P2
    // nSteps [step] = omega [step/s] * deltaT [ms] / 1000
    // È stato fatto prima per non riscrivere lo stesso calcolo
    // per tre modalità diverse
    int nSteps = round(parameters[P_OMEGA] * parameters[P_PULSE_DURATION] / 1000);

    // Imposto durata del tempo di ON del trigger
    // sul pin STEP
    steppersArray[0].setMinPulseWidth(parameters[P_TRIGGER_LENGTH]);
    steppersArray[1].setMinPulseWidth(parameters[P_TRIGGER_LENGTH]);
    steppersArray[2].setMinPulseWidth(parameters[P_TRIGGER_LENGTH]);
    
    // Modalità continua
    if (mode == "R")
    {      
      // Imposto velocità moltiplicata per direzione e
      // giro fino a che non riceve il segnale di stop
      steppersArray[motor_ind].setSpeed(parameters[P_OMEGA]*parameters[P_DIRECTION]);
      do
      {
        steppersArray[motor_ind].runSpeed();
        if (Serial.available() > 0)
        {
          command = Serial.readString();
        }
      }
      while (command != "S");
    }

    // Modalità ritorno a posizione iniziale
    else if (mode == "Z")
    {
      // È necessario impostare prima la posizione bersaglio
      // perché chiamare move o moveTo ricalcola la velocità
      steppersArray[motor_ind].moveTo(0);
      steppersArray[motor_ind].setSpeed(parameters[P_OMEGA]);
      
      // Giro fino a che non arriva al bersaglio
      steppersArray[motor_ind].runSpeedUntilPosition();
    }

    // Imposto posizione corrente come posizione iniziale
    else if (mode == "0")
    {
      steppersArray[motor_ind].setCurrentPosition(0);
    }

    // Modalità calibrazione
    else if (mode == "D")
    {
      // Vedere documentazione della funzione
      runSpeedUntilPositionWithSampling(&steppersArray[motor_ind], parameters[P_OMEGA], parameters[P_PULSE_DURATION], parameters[P_PULSES_FOR_CALIBRATION], parameters[P_INTERVAL_BETWEEN_PULSES]);
    }

    // Modalità protocollo a singolo motore.
    // Serviva al test di impulsi del motore.
    else if (mode == "P0")
    {
      do
      {
        // Imposto numero di step da eseguire e velocità
        // N.B. In questa modalità di debug è possibile
        // fare step all'indietro
        steppersArray[motor_ind].move(nSteps*parameters[P_DIRECTION]);
        steppersArray[motor_ind].setSpeed(parameters[P_OMEGA]);

        // Faccio girare il motore con i parametri sopra impostati
        // e invia un segnale di TTL
        runSpeedUntilPositionWithTTL(&steppersArray[motor_ind], TTL_N);
        if (Serial.available() > 0)
        {
          command = Serial.readString();
        }

        // Genero un ritardo pari all'isi scelto
        // meno la durata dell'impulso
        delay(ISI - parameters[P_PULSE_DURATION]+random(-ISI_JITTER,ISI_JITTER)); //jitter
      }
      while (command != "S");
    }
    
    // Modalità a due motori con un gusto
    else if (mode == "P1")
    {
      // Eseguo degli impulsi iniziali per far abituare la lingua
      for (int n = 0; n < STARTING_PULSES; n++)
      {
          steppersArray[0].move(nSteps);
          steppersArray[0].setSpeed(parameters[P_OMEGA]);
          runSpeedUntilPositionWithTTL(&steppersArray[0], TTL_D);
         
          if (checkInterrupts()) { return; }
          
          delay(ISI - parameters[P_PULSE_DURATION]+random(-ISI_JITTER,ISI_JITTER));//jitter
      }
      
      // Itero P_TASTANT_BLOCKS volte
      for (int i = 0; i < parameters[P_TASTANT_BLOCKS]; i++)
      {

        // Per ogni blocco itero P_NEUTRAL_PULSES volte per il neutro
        for (int j = 0; j < parameters[P_NEUTRAL_PULSES]; j++)
        {
          steppersArray[0].move(nSteps);
          steppersArray[0].setSpeed(parameters[P_OMEGA]);

          // I primi P_PULSES_TO_DISCARD impulsi vengono inviati senza TTL
          // i restanti con il TTL opportuno
          if (j < parameters[P_PULSES_TO_DISCARD])
          {
            runSpeedUntilPositionWithTTL(&steppersArray[0], TTL_D);
          }
          else
          {
            runSpeedUntilPositionWithTTL(&steppersArray[0], TTL_N);
          }

          // Controllo se ci sono segnali di interruzione
          // o attesa
          if (checkInterrupts()) { return; }
          
          delay(ISI - parameters[P_PULSE_DURATION]+random(-ISI_JITTER,ISI_JITTER));//jitter
        }

        // Dopo gli impulsi di neutro invio P_TASTANT_PULSES di gusto con stesso protocollo
        for (int k = 0; k < parameters[P_TASTANT_PULSES]; k++)
        {
          steppersArray[motor_ind].move(nSteps);
          steppersArray[motor_ind].setSpeed(parameters[P_OMEGA]);
          
          if (k < parameters[P_PULSES_TO_DISCARD])
          {
            runSpeedUntilPositionWithTTL(&steppersArray[motor_ind], TTL_D);
          }
          else
          {
            runSpeedUntilPositionWithTTL(&steppersArray[motor_ind], TTL_G1);
          }
          
          if (checkInterrupts()) { return; }
          
          delay(ISI - parameters[P_PULSE_DURATION]+random(-ISI_JITTER,ISI_JITTER));//jitter
        }
      }
    }

    // Modalità definitiva a 3 motori e due gusti
    else if (mode == "P2")
    {
      // Eseguo degli impulsi iniziali per far abituare la lingua
      for (int n = 0; n < STARTING_PULSES; n++)
      {
          steppersArray[0].move(nSteps);
          steppersArray[0].setSpeed(parameters[P_OMEGA]);
          runSpeedUntilPositionWithTTL(&steppersArray[0], TTL_D);
          if (checkInterrupts()) { return; }
          
          delay(ISI - parameters[P_PULSE_DURATION]+random(-ISI_JITTER,ISI_JITTER));
      }
      
      // L'unica modalità in cui oltre ai parametri dopo viene
      // inviata anche una lista che presenta l'ordine casuale
      // con cui devono essere mandati i gusti.
      // Viene chiamata readModeParameters per leggere i vari
      // elementi della lista.
      // A parte questo il protocollo è identico a P1
      // NB: P_TASTANT_BLOCKS indica il numero di blocchi per OGNI
      // gusto, per questo l'array è lungo P_TASTANT_BLOCKS * 2
      long randomBlocks[parameters[P_TASTANT_BLOCKS] * 2];
      readModeParameters(&command, randomBlocks, parameters[P_TASTANT_BLOCKS] * 2);
      /*for (int x = 0; x < (parameters[P_TASTANT_BLOCKS] * 2); x++)
      {
        Serial.print(String(randomBlocks[x]) + ",");
      }*/
      Serial.println();
      for (int i = 0; i < parameters[P_TASTANT_BLOCKS] * 2; i++)
      {
        for (int j = 0; j < parameters[P_NEUTRAL_PULSES]; j++)
        {
          steppersArray[0].move(nSteps);
          steppersArray[0].setSpeed(parameters[P_OMEGA]);
          
          if (j < parameters[P_PULSES_TO_DISCARD])
          {
            runSpeedUntilPositionWithTTL(&steppersArray[0], TTL_D);
          }
          else
          {
            runSpeedUntilPositionWithTTL(&steppersArray[0], TTL_N);
          }
          
          if (checkInterrupts()) { return; }
          
          delay(ISI - parameters[P_PULSE_DURATION]+random(-ISI_JITTER,ISI_JITTER));//jitter
        }
        for (int k = 0; k < parameters[P_TASTANT_PULSES]; k++)
        {
          steppersArray[randomBlocks[i]].move(nSteps);
          steppersArray[randomBlocks[i]].setSpeed(parameters[P_OMEGA]);
          
          if (k < parameters[P_PULSES_TO_DISCARD])
          {
            runSpeedUntilPositionWithTTL(&steppersArray[randomBlocks[i]], TTL_D);
          }
          else
          {
            runSpeedUntilPositionWithTTL(&steppersArray[randomBlocks[i]], TTL_N+randomBlocks[i]);
          }
          
          if (checkInterrupts()) { return; }
          
          delay(ISI - parameters[P_PULSE_DURATION]+random(-ISI_JITTER,ISI_JITTER));//jitter
        }
      }
    }
  }
}
