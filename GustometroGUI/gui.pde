/* =========================================================
 * ====                   WARNING                        ===
 * =========================================================
 * The code in this tab has been generated from the GUI form
 * designer and care should be taken when editing this file.
 * Only add/edit code inside the event handlers i.e. only
 * use lines between the matching comment tags. e.g.

 void myBtnEvents(GButton button) { //_CODE_:button1:12356:
     // It is safe to enter your event code here  
 } //_CODE_:button1:12356:
 
 * Do not rename this tab!
 * =========================================================
 */

public void tf_pulseDuration_change(GTextField source, GEvent event) { //_CODE_:tf_pulseDuration:979747:
  // Se cambio la durata dell'impulso fisso il flusso e cambio il volume
  try
  {
    float duration = Float.parseFloat(source.getText()) / 1000;
    float volume = Float.parseFloat(tf_pulseVolume.getText());
    float flux = volume / duration;
    tf_flux.setText(String.format("%.2f", flux));
    tf_omega.setText(String.format("%.2f", flux / OMEGA_FLUX_COEFFICIENT));
  }
  catch (NumberFormatException e)
  {
    tf_flux.setText("");
    tf_omega.setText("");
  }
} //_CODE_:tf_pulseDuration:979747:

public void tf_omega_change(GTextField source, GEvent event) { //_CODE_:tf_omega:749316:
  // Se cambio la velocità angolare cambio il flusso e fisso la durata
  // per cambiare il volume
  try
  {
    float omega = Float.parseFloat(source.getText());
    float flux = omega * OMEGA_FLUX_COEFFICIENT; // step/s * 2,7154672e-6 l/step
    float duration = Float.parseFloat(tf_pulseDuration.getText()) / 1000;
    tf_flux.setText(String.format("%.2f", flux));
    tf_pulseVolume.setText(String.format("%.2f", flux * duration));
  }
  catch (NumberFormatException e)
  {
    tf_flux.setText("");
    tf_pulseVolume.setText("");
  }
} //_CODE_:tf_omega:749316:

public void tf_neutralPulses_change(GTextField source, GEvent event) { //_CODE_:tf_neutralPulses:277226:
} //_CODE_:tf_neutralPulses:277226:

public void tf_tastantPulses_change(GTextField source, GEvent event) { //_CODE_:tf_tastantPulses:987867:
} //_CODE_:tf_tastantPulses:987867:

public void tf_tastantBlocks_change(GTextField source, GEvent event) { //_CODE_:tf_tastantBlocks:306918:
} //_CODE_:tf_tastantBlocks:306918:

public void bt_backToZero_click(GButton source, GEvent event) { //_CODE_:bt_backToZero:962881:
  String params = getParameters();
  if (params != "")
  {
    port.write("Z\n" + dl_activeChannel.getSelectedIndex() + "\n" + params);
  }
} //_CODE_:bt_backToZero:962881:

public void bt_startCalibration_click(GButton source, GEvent event) { //_CODE_:bt_startCalibration:350868:
  String params = getParameters();
  if (params != "")
  {
    calibrationRoutine = cb_routine.isSelected();
    calibrationVolume = (int) round(Float.parseFloat(tf_pulseVolume.getText())) *
        Integer.parseInt(tf_pulsesForCalibration.getText());

    String path = tf_calibrationFile.getText();
    graph = createWriter(String.format("%s/graph_%d%d_%d%d_%d.txt", path, 
      day(), month(), hour(), minute(), second()));
    String firstLine = String.format("Volume: %s,   Durata: %s,   Impulsi: %s,   Intervallo: %s",
      tf_pulseVolume.getText(), tf_pulseDuration.getText(), tf_pulsesForCalibration.getText(), tf_calibrationInterval.getText());
    graph.println(firstLine);
    
    port.write("D\n" + dl_activeChannel.getSelectedIndex() + "\n" + params);
  }
} //_CODE_:bt_startCalibration:350868:

public void bt_protocol_click(GButton source, GEvent event) { //_CODE_:bt_protocol:446130:
  String params = getParameters();
  if (params != "")
  {  
    int nMotors = dl_nChannels.getSelectedIndex();
    
    if (nMotors == 0)
    {
      port.write("P0\n" + dl_activeChannel.getSelectedIndex() + "\n" + params);
    }
    else if ((nMotors == 1) && (dl_activeChannel.getSelectedIndex() != 0))
    {
      port.write("P1\n" + dl_activeChannel.getSelectedIndex() + "\n" + params);
    }
    else if ((nMotors == 1) && (dl_activeChannel.getSelectedIndex() == 0))
    {
      println("Selezionare come canale attivo un canale gustativo valido (G1 o G2)");
    }
    else
    {
      int tastantBlocks = Integer.parseInt(tf_tastantBlocks.getText());
      
      /*
       * Creo due array, uno più grande per registrare la sequenza di gusti
       * casuale e uno piccolo la metà come ausiliario per costruirlo.
       * Riempio l'array più piccolo di 1 e lo copio nella prima metà del
       * più grande; poi lo riempio di 2 e lo copio nella seconda metà.
       * Infine mi creo una lista dall'array, la quale a differenza di esso
       * è mutevole, e la riordino casualmente.
       */
      Integer[] blocks = new Integer[tastantBlocks*2]; Integer[] temp = new Integer[tastantBlocks];
      Arrays.fill(temp, 1); System.arraycopy(temp,0,blocks,0,tastantBlocks);
      Arrays.fill(temp, 2); System.arraycopy(temp,0,blocks,tastantBlocks,tastantBlocks);
      List<Integer> blocksList = Arrays.asList(blocks);
      Collections.shuffle(blocksList);
      
      String command = "P2\n3\n" + params;
        
      for (int i = 0; i < tastantBlocks * 2; i++)
      {
        command = command.concat(blocksList.get(i) + ",");
      }
      command = command.concat("\n");
      
      port.write(command);
    }
  }
} //_CODE_:bt_protocol:446130:

public void bt_stop_click(GButton source, GEvent event) { //_CODE_:bt_stop:771483:
  calibrationRoutine = false;
  port.write("S");
} //_CODE_:bt_stop:771483:

public void tf_flux_change(GTextField source, GEvent event) { //_CODE_:tf_flux:819703:
  // Se cambia il flusso cambio la velocità angolare e fisso la durata per
  // cambiare il volume
  try
  {
    float flux = Float.parseFloat(source.getText());
    float duration = Float.parseFloat(tf_pulseDuration.getText()) / 1000;
    tf_omega.setText(String.format("%.2f", flux / OMEGA_FLUX_COEFFICIENT));
    tf_pulseVolume.setText(String.format("%.2f", flux * duration));
  }
  catch (NumberFormatException e)
  {
    tf_omega.setText("");
    tf_pulseVolume.setText("");
  }
} //_CODE_:tf_flux:819703:

public void cb_direction_clicked(GCheckbox source, GEvent event) { //_CODE_:cb_direction:386022:
} //_CODE_:cb_direction:386022:

public void bt_run_click(GButton source, GEvent event) { //_CODE_:bt_run:524987:
  String params = getParameters();
  if (params != "")
  {
    if (event == GEvent.PRESSED)
    {
      port.write("R\n" + dl_activeChannel.getSelectedIndex() + "\n" + params);
    }
    if ((event == GEvent.CLICKED) || (event == GEvent.RELEASED))
    {
      port.write("S");
    }
  }
} //_CODE_:bt_run:524987:

public void dl_activeChannel_click(GDropList source, GEvent event) { //_CODE_:dl_activeChannel:674154:
} //_CODE_:dl_activeChannel:674154:

public void bt_setZero_click(GButton source, GEvent event) { //_CODE_:bt_setZero:477074:
  port.write("0\n" + dl_activeChannel.getSelectedIndex() + "\n");
} //_CODE_:bt_setZero:477074:

public void tf_pulsesForCalibration_change(GTextField source, GEvent event) { //_CODE_:tf_pulsesForCalibration:431416:
} //_CODE_:tf_pulsesForCalibration:431416:

public void tf_calibrationInterval_change(GTextField source, GEvent event) { //_CODE_:tf_calibrationInterval:993779:
} //_CODE_:tf_calibrationInterval:993779:

public void dl_nChannels_click(GDropList source, GEvent event) { //_CODE_:dl_nChannels:717573:
} //_CODE_:dl_nChannels:717573:

public void tf_pulsesToDiscard_change2(GTextField source, GEvent event) { //_CODE_:tf_pulsesToDiscard:998214:
} //_CODE_:tf_pulsesToDiscard:998214:

public void bt_calibrationFile_click(GButton source, GEvent event) { //_CODE_:bt_calibrationFile:829982:
  if (event == GEvent.CLICKED)
  {
    selectFolder("Seleziona cartella: ", "folderSelected");
  }
} //_CODE_:bt_calibrationFile:829982:

public void tf_calibrationFile_change(GTextField source, GEvent event) { //_CODE_:tf_calibrationFile:463437:
} //_CODE_:tf_calibrationFile:463437:

public void tf_triggerLength_change(GTextField source, GEvent event) { //_CODE_:tf_triggerLength:304230:
} //_CODE_:tf_triggerLength:304230:

public void tf_pulseVolume_change(GTextField source, GEvent event) { //_CODE_:tf_pulseVolume:342424:
  // Se cambio il volume fisso la durata e cambio il flusso e di
  // conseguenza la velocità angolare
  try
  {
    float volume = Float.parseFloat(source.getText());
    float duration = Float.parseFloat(tf_pulseDuration.getText()) / 1000;
    float flux = volume / duration;
    tf_flux.setText(String.format("%.2f", flux));
    tf_omega.setText(String.format("%.2f", flux / OMEGA_FLUX_COEFFICIENT));
  }
  catch (NumberFormatException e)
  {
    tf_flux.setText("");
    tf_omega.setText("");
  }
} //_CODE_:tf_pulseVolume:342424:

public void cb_routine_clicked(GCheckbox source, GEvent event) { //_CODE_:cb_routine:594851:
} //_CODE_:cb_routine:594851:

public void bt_wait_click(GButton source, GEvent event) { //_CODE_:bt_wait:587263:
  port.write("W");
} //_CODE_:bt_wait:587263:



// Create all the GUI controls. 
// autogenerated do not edit
public void createGUI(){
  G4P.messagesEnabled(false);
  G4P.setGlobalColorScheme(GCScheme.BLUE_SCHEME);
  G4P.setMouseOverEnabled(false);
  surface.setTitle("Gustometro GUI");
  lbl_pulseDuration = new GLabel(this, 5, 33, 162, 20);
  lbl_pulseDuration.setTextAlign(GAlign.CENTER, GAlign.MIDDLE);
  lbl_pulseDuration.setText("Durata impulso (ms)");
  lbl_pulseDuration.setOpaque(false);
  tf_pulseDuration = new GTextField(this, 172, 33, 47, 20, G4P.SCROLLBARS_NONE);
  tf_pulseDuration.setText("100");
  tf_pulseDuration.setOpaque(true);
  tf_pulseDuration.addEventHandler(this, "tf_pulseDuration_change");
  tf_omega = new GTextField(this, 172, 5, 47, 20, G4P.SCROLLBARS_NONE);
  tf_omega.setText("368.26");
  tf_omega.setOpaque(true);
  tf_omega.addEventHandler(this, "tf_omega_change");
  lbl_omega = new GLabel(this, 5, 5, 162, 20);
  lbl_omega.setTextAlign(GAlign.CENTER, GAlign.MIDDLE);
  lbl_omega.setText("Velocità angolare (step/s)");
  lbl_omega.setOpaque(false);
  lbl_neutralPulses = new GLabel(this, 5, 61, 162, 20);
  lbl_neutralPulses.setTextAlign(GAlign.CENTER, GAlign.MIDDLE);
  lbl_neutralPulses.setText("Impulsi neutro per blocco");
  lbl_neutralPulses.setOpaque(false);
  tf_neutralPulses = new GTextField(this, 172, 61, 47, 20, G4P.SCROLLBARS_NONE);
  tf_neutralPulses.setText("4");
  tf_neutralPulses.setOpaque(true);
  tf_neutralPulses.addEventHandler(this, "tf_neutralPulses_change");
  lbl_tastantPulses = new GLabel(this, 5, 89, 162, 20);
  lbl_tastantPulses.setTextAlign(GAlign.CENTER, GAlign.MIDDLE);
  lbl_tastantPulses.setText("Impulsi gusto per blocco");
  lbl_tastantPulses.setOpaque(false);
  tf_tastantPulses = new GTextField(this, 172, 89, 47, 20, G4P.SCROLLBARS_NONE);
  tf_tastantPulses.setText("4");
  tf_tastantPulses.setOpaque(true);
  tf_tastantPulses.addEventHandler(this, "tf_tastantPulses_change");
  tf_tastantBlocks = new GTextField(this, 172, 117, 47, 20, G4P.SCROLLBARS_NONE);
  tf_tastantBlocks.setText("20");
  tf_tastantBlocks.setOpaque(true);
  tf_tastantBlocks.addEventHandler(this, "tf_tastantBlocks_change");
  bt_backToZero = new GButton(this, 15, 285, 80, 40);
  bt_backToZero.setText("Ritorno a posizione zero");
  bt_backToZero.addEventHandler(this, "bt_backToZero_click");
  bt_startCalibration = new GButton(this, 105, 285, 80, 40);
  bt_startCalibration.setText("Inizia calibrazione");
  bt_startCalibration.addEventHandler(this, "bt_startCalibration_click");
  bt_protocol = new GButton(this, 195, 285, 80, 40);
  bt_protocol.setText("Esegui protocollo");
  bt_protocol.addEventHandler(this, "bt_protocol_click");
  bt_stop = new GButton(this, 285, 285, 80, 40);
  bt_stop.setText("Interrompi");
  bt_stop.addEventHandler(this, "bt_stop_click");
  lbl_tastantBlocks = new GLabel(this, 5, 117, 162, 20);
  lbl_tastantBlocks.setTextAlign(GAlign.CENTER, GAlign.MIDDLE);
  lbl_tastantBlocks.setText("Blocchi per gusto");
  lbl_tastantBlocks.setOpaque(false);
  tf_flux = new GTextField(this, 403, 5, 47, 20, G4P.SCROLLBARS_NONE);
  tf_flux.setText("1000.00");
  tf_flux.setOpaque(true);
  tf_flux.addEventHandler(this, "tf_flux_change");
  cb_direction = new GCheckbox(this, 5, 201, 173, 20);
  cb_direction.setIconPos(GAlign.EAST);
  cb_direction.setTextAlign(GAlign.CENTER, GAlign.MIDDLE);
  cb_direction.setText("Inversione motore");
  cb_direction.setOpaque(false);
  cb_direction.addEventHandler(this, "cb_direction_clicked");
  bt_run = new GButton(this, 375, 285, 80, 40);
  bt_run.setText("Gira");
  bt_run.addEventHandler(this, "bt_run_click");
  dl_activeChannel = new GDropList(this, 403, 89, 47, 80, 3, 10);
  dl_activeChannel.setItems(loadStrings("list_674154"), 0);
  dl_activeChannel.addEventHandler(this, "dl_activeChannel_click");
  lbl_flux = new GLabel(this, 236, 5, 162, 20);
  lbl_flux.setTextAlign(GAlign.CENTER, GAlign.MIDDLE);
  lbl_flux.setText("Velocità di flusso (ul/s)");
  lbl_flux.setOpaque(false);
  bt_setZero = new GButton(this, 15, 235, 80, 40);
  bt_setZero.setText("Imposta posizione zero");
  bt_setZero.addEventHandler(this, "bt_setZero_click");
  lbl_pulsesForCalibration = new GLabel(this, 236, 117, 162, 20);
  lbl_pulsesForCalibration.setTextAlign(GAlign.CENTER, GAlign.MIDDLE);
  lbl_pulsesForCalibration.setText("Impulsi per calibrazione");
  lbl_pulsesForCalibration.setOpaque(false);
  tf_pulsesForCalibration = new GTextField(this, 403, 117, 47, 20, G4P.SCROLLBARS_NONE);
  tf_pulsesForCalibration.setText("12");
  tf_pulsesForCalibration.setOpaque(true);
  tf_pulsesForCalibration.addEventHandler(this, "tf_pulsesForCalibration_change");
  lbl_calibrationInterval = new GLabel(this, 236, 145, 162, 20);
  lbl_calibrationInterval.setTextAlign(GAlign.CENTER, GAlign.MIDDLE);
  lbl_calibrationInterval.setText("Intervallo impulsi cal. (ms)");
  lbl_calibrationInterval.setOpaque(false);
  tf_calibrationInterval = new GTextField(this, 403, 145, 47, 20, G4P.SCROLLBARS_NONE);
  tf_calibrationInterval.setText("6000");
  tf_calibrationInterval.setOpaque(true);
  tf_calibrationInterval.addEventHandler(this, "tf_calibrationInterval_change");
  dl_nChannels = new GDropList(this, 403, 61, 47, 60, 2, 10);
  dl_nChannels.setItems(loadStrings("list_717573"), 2);
  dl_nChannels.addEventHandler(this, "dl_nChannels_click");
  lbl_nChannels = new GLabel(this, 236, 61, 162, 20);
  lbl_nChannels.setTextAlign(GAlign.CENTER, GAlign.MIDDLE);
  lbl_nChannels.setText("Canali gustativi protocollo");
  lbl_nChannels.setOpaque(false);
  lbl_activeChannel = new GLabel(this, 236, 89, 162, 20);
  lbl_activeChannel.setTextAlign(GAlign.CENTER, GAlign.MIDDLE);
  lbl_activeChannel.setText("Canale attivo");
  lbl_activeChannel.setOpaque(false);
  lbl_pulsesToDiscard = new GLabel(this, 5, 145, 162, 20);
  lbl_pulsesToDiscard.setTextAlign(GAlign.CENTER, GAlign.MIDDLE);
  lbl_pulsesToDiscard.setText("Impulsi da scartare");
  lbl_pulsesToDiscard.setOpaque(false);
  tf_pulsesToDiscard = new GTextField(this, 172, 145, 47, 20, G4P.SCROLLBARS_NONE);
  tf_pulsesToDiscard.setText("1");
  tf_pulsesToDiscard.setOpaque(true);
  tf_pulsesToDiscard.addEventHandler(this, "tf_pulsesToDiscard_change2");
  bt_calibrationFile = new GButton(this, 423, 201, 27, 20);
  bt_calibrationFile.setText("...");
  bt_calibrationFile.addEventHandler(this, "bt_calibrationFile_click");
  tf_calibrationFile = new GTextField(this, 236, 201, 182, 20, G4P.SCROLLBARS_NONE);
  tf_calibrationFile.setOpaque(true);
  tf_calibrationFile.addEventHandler(this, "tf_calibrationFile_change");
  lbl_calibrationFile = new GLabel(this, 236, 173, 162, 20);
  lbl_calibrationFile.setTextAlign(GAlign.CENTER, GAlign.MIDDLE);
  lbl_calibrationFile.setText("File per la calibrazione");
  lbl_calibrationFile.setOpaque(false);
  tf_triggerLength = new GTextField(this, 172, 173, 47, 20, G4P.SCROLLBARS_NONE);
  tf_triggerLength.setText("2");
  tf_triggerLength.setOpaque(true);
  tf_triggerLength.addEventHandler(this, "tf_triggerLength_change");
  lbl_triggerLength = new GLabel(this, 5, 173, 162, 20);
  lbl_triggerLength.setTextAlign(GAlign.CENTER, GAlign.MIDDLE);
  lbl_triggerLength.setText("Durata del trigger (us)");
  lbl_triggerLength.setOpaque(false);
  tf_pulseVolume = new GTextField(this, 403, 33, 47, 20, G4P.SCROLLBARS_NONE);
  tf_pulseVolume.setText("100.00");
  tf_pulseVolume.setOpaque(true);
  tf_pulseVolume.addEventHandler(this, "tf_pulseVolume_change");
  lbl_pulseVolume = new GLabel(this, 236, 33, 162, 20);
  lbl_pulseVolume.setTextAlign(GAlign.CENTER, GAlign.MIDDLE);
  lbl_pulseVolume.setText("Volume (ul)");
  lbl_pulseVolume.setOpaque(false);
  cb_routine = new GCheckbox(this, 236, 229, 173, 20);
  cb_routine.setIconPos(GAlign.EAST);
  cb_routine.setTextAlign(GAlign.CENTER, GAlign.MIDDLE);
  cb_routine.setText("Routine di calibrazione");
  cb_routine.setOpaque(false);
  cb_routine.addEventHandler(this, "cb_routine_clicked");
  bt_wait = new GButton(this, 105, 235, 80, 40);
  bt_wait.setText("Attesa/ripresa attività");
  bt_wait.addEventHandler(this, "bt_wait_click");
}

// Variable declarations 
// autogenerated do not edit
GLabel lbl_pulseDuration; 
GTextField tf_pulseDuration; 
GTextField tf_omega; 
GLabel lbl_omega; 
GLabel lbl_neutralPulses; 
GTextField tf_neutralPulses; 
GLabel lbl_tastantPulses; 
GTextField tf_tastantPulses; 
GTextField tf_tastantBlocks; 
GButton bt_backToZero; 
GButton bt_startCalibration; 
GButton bt_protocol; 
GButton bt_stop; 
GLabel lbl_tastantBlocks; 
GTextField tf_flux; 
GCheckbox cb_direction; 
GButton bt_run; 
GDropList dl_activeChannel; 
GLabel lbl_flux; 
GButton bt_setZero; 
GLabel lbl_pulsesForCalibration; 
GTextField tf_pulsesForCalibration; 
GLabel lbl_calibrationInterval; 
GTextField tf_calibrationInterval; 
GDropList dl_nChannels; 
GLabel lbl_nChannels; 
GLabel lbl_activeChannel; 
GLabel lbl_pulsesToDiscard; 
GTextField tf_pulsesToDiscard; 
GButton bt_calibrationFile; 
GTextField tf_calibrationFile; 
GLabel lbl_calibrationFile; 
GTextField tf_triggerLength; 
GLabel lbl_triggerLength; 
GTextField tf_pulseVolume; 
GLabel lbl_pulseVolume; 
GCheckbox cb_routine; 
GButton bt_wait; 
