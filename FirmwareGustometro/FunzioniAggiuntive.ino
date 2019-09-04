/*
 * Alcune funzioni in un file separato per una maggiore leggibilità.
 */

/*
 * Definisco funzione per leggere i parametri della seriale.
 * I parametri sono separati da una virgola e il controllo
 * per vedere se sono interi è stato già fatto lato pc.
 * Invece di ritornare un array, semplicemente passo come
 * parametro il puntatore dell'array da modificare.
 * Questa funzione è usata anche per leggere la lista dei
 * blocchi di gusto da eseguire, pertanto è stato aggiunto un 
 * parametro len che specifica la lunghezza dell'array
 * bersaglio (sarà in tutti i casi uguale a MAX_PARAMS
 * tranne in quel caso specifico).
 * Leggere la questione sui vettori passati come argomento
 * qui: https://stackoverflow.com/questions/11829830/c-passing-an-array-pointer-as-a-function-argument
 * Per via di ciò ho usato la notazione con il puntatore e
 * non quella commentata.
 */
//void readModeParameters(String params, long parameters[], int len)
void readModeParameters(String *params, long *parameters, int len)
{
  for (int i = 0; i < len; i++)
  {
    // Prendo la sotto stringa fino alla virgola (esclusa),
    // la converto in intero, la inserisco nell'array e
    // taglio la stringa principale.
    String temp = params->substring(0,params->indexOf(','));
    parameters[i] = temp.toInt();
    *params = params->substring(params->indexOf(',') + 1);
  }
}

/*
 * Funzione che controlla la seriale dopo ogni loop per
 * verificare se ci sono segnali di attesa o di interruzione.
 * L'attesa viene risolta all'interno della funzione,
 * mentre l'interruzione viene gestita ritornando true o
 * false e facendo il controllo nel loop. Si è fatto così
 * per evitare di riscrivere più volte lo stesso codice.
 */
boolean checkInterrupts()
{
  if (Serial.available() > 0)
  {
    command = Serial.readString();
    if (command == "S")
    {
      return true;
    }
    else if (command == "W")
    {
      do
      {
        if (Serial.available() >= 0)
        {
          command = Serial.readString();
        }
      }
      while (command != "W");
    }
    return false;
  }
}

/* 
 *  Mi creo una funzione che verrà chiamata durante i
 *  protocolli di acquisizione. Questo per 
 *  permettere di generare un segnale di trigger
 *  diverso a seconda dello stimolo inviato.
 *  Essendo tre canali gustativi bastano due bit
 *  per poter generare un trigger diverso per ognuno.
 *  Semplicemente si converte il valore decimale in binario
 *  e si mandano ad alto i pin opportuni
 *  
 *  0d = 00b -> da scartare
 *  1d = 01b -> neutro
 *  2d = 10b -> gusto 1
 *  3d = 11b -> gusto 2
 *  
 *  NB: è nessario passare il puntatore, non l'oggetto,
 *  altrimenti non viene aggiornata la posizione corrente
 *  dell'oggetto, bensì quella del parametro.
 */
void runSpeedUntilPositionWithTTL(AccelStepper *motor, int ttlpin)
{
  // Mando i pin opportuni ad HIGH
  digitalWrite(TTL_LSB_PIN, ttlpin & 1);
  digitalWrite(TTL_MSB_PIN, (ttlpin >> 1) & 1);

  // Calcolo il numero di step che vanno fatti prima di
  // rimandare i pin a LOW partendo dalla velocità
  // angolare e la durata del TTL
  long startingPosition = motor->currentPosition();
  long ttlSteps = motor->speed() * TTL_LENGTH / 1000;
  
  // Faccio girare il motore a velocità costante
  while (motor->distanceToGo() != 0)
  {
    // In più dopo TTL_LENGTH ms riporta i pin su LOW
    // Il controllo è più comodo farlo sul numero dei passi
    // che sul tempo trascorso
    if ((motor->currentPosition() - startingPosition) > ttlSteps)
    {
      digitalWrite(TTL_LSB_PIN, LOW);
      digitalWrite(TTL_MSB_PIN, LOW);
    }
    motor->runSpeedToPosition();
  }
}

/* 
 *  Mi creo una funzione che verrà chiamata per la
 *  calibrazione del dispositivo.
 *  Il principio di base è quello dell'esempio di Arduino
 *  BlinkWithoutDelay, perché dal momento che i delay sono
 *  bloccanti, bisognava trovare un altro metodo per 
 *  campionare mentre i motori girano.
 *  Vengono registrate delle variabili che segnano l'istante
 *  precedente in cui un "blocco" di codice è stato eseguito,
 *  e una che segna l'istante corrente. Quando la differenza è
 *  uguale al periodo che mi serve eseguo il blocco e aggiorno
 *  la variabile.
 *  Contremporaneamente vengono inviati su seriale valore di
 *  campionamento del pin step del driver e della lastra di
 *  calibrazione tramite un array di byte.
 *  Servono in totale 6 byte, 4 per il long perché in Uno
 *  occupano 32 bit, 2 per l'int perché ne occupa 16, mentre
 *  il motore essendo booleano è stato inglobato dentro il
 *  MSB dell'int perché su 16 bit ne servono solo 10 vista
 *  la quantizzaione di Arduino. Questo è stato fatto usando
 *  una maschera 80h = 10000000b.
 *  La codifica è di tipo big endian e il valore che indica
 *  la fine della trasmissione è l'array di tutti gli elementi
 *  pari a FFh.
 */ 

void sendPacket(unsigned long currTime, int board, bool motor)
{
  // Codifico in big endian e applico se necessario
  // la maschera
  bufferTX[0] = (currTime >> 24) & 0xff;
  bufferTX[1] = (currTime >> 16) & 0xff;
  bufferTX[2] = (currTime >> 8) & 0xff;
  bufferTX[3] = currTime & 0xff;
  bufferTX[4] = motor ? (board >> 8) & 0xff | 0x80 : (board >> 8) & 0xff;
  bufferTX[5] = board & 0xff;

  // Invio il pachetto
  Serial.write(bufferTX, PACKET_SIZE);
}
 
void runSpeedUntilPositionWithSampling(AccelStepper *motor, long omega, long pulseDuration, long nPulses, long pulsesInterval)
{
  // Riazzero la posizione bersaglio
  // Chiamata necessaria in caso sia stata usata prima
  // la modalità continua e la posizione corrente 
  // differisce da quella bersaglio
  motor->moveTo(motor->currentPosition());
  
  int runsToStop = nPulses;
  int voltage_board;
  bool voltage_motor;
  pulsesInterval *= 1000;
  
  unsigned long currentTime = micros();
  unsigned long previousSamplingTime = currentTime;
  unsigned long timeOffset = currentTime;
  // Il primo trigger avviene dopo 1,5s
  unsigned long previousPulseTime = timeOffset - pulsesInterval + 1500000;
  
  // Itera finché ci sono impulsi da eseguire
  while (runsToStop >= 0)
  {
    currentTime = micros();

    // Blocco di campionamento
    if (currentTime - previousSamplingTime >= SAMPLING_TIME)
    {
      previousSamplingTime = currentTime;
      voltage_board = analogRead(PLATE_SAMPLING_PIN);
      voltage_motor = digitalRead(MOTOR_SAMPLING_PIN);
      sendPacket(currentTime - timeOffset, voltage_board, voltage_motor);
    }

    // Blocco di inizio impulso
    if (currentTime - previousPulseTime >= pulsesInterval)
    {
      runsToStop -= 1;
      previousPulseTime = currentTime;

      if (runsToStop >= 0)
      {
        motor->move(omega * pulseDuration / 1000);
        motor->setSpeed(omega);
      }
    }

    // Gira il motore quando necessario
    motor->runSpeedToPosition();

    if (checkInterrupts()) { break; }
  }

  // Attende la fine della trasmissione seriale in uscita
  Serial.flush();

  // Invio comando per indicare a processing di chiudere il file
  memset(bufferTX,0xff,PACKET_SIZE);
  Serial.write(bufferTX,PACKET_SIZE);
}
