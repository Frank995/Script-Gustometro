# Analisi di tutta la routine di calibrazione, che mostra i risultati come immagini 2D

import os
import numpy as np
import matplotlib
import matplotlib.pyplot as plt
import matplotlib.cm as cm
from FunzioniDiAnalisi import *

# Minimo, massimo e intervallo di durata e volume
# Calcolo inoltre lo scostamento sulla relativa
# dimensione dell'array
DURATION_START = 100
DURATION_END = 1000
DURATION_STEP = 100
DURATION_ARRAYSHIFT = DURATION_START // DURATION_STEP
VOLUME_START = 200
VOLUME_END = 1000
VOLUME_STEP = 100
VOLUME_ARRAYSHIFT = VOLUME_START // VOLUME_STEP
FLUX_TO_OMEGA = 2.715

# Scrivere il path della cartella con i file di calibrazione
# Cambio la cartella di lavoro con quella in cui sono presenti i file
os.chdir("C:\\Users\\Francesco\\Desktop\\RoutineCalibrazione")

# Inizializzo gli calcolandomi le dimensioni dallle variabili di cui sopra
# Sono state inizializzati uno a 1 e uno a 0 perché se fossero stati
# inizializzati entrambi a 1, quando dovevo calcolare il coefficiente di 
# variazioni su coppie di parametri non acquisite si avrebbe avuto un
# errore di divisione per zero
meansArray = np.ones(((DURATION_END - DURATION_START) // DURATION_STEP + 1, (VOLUME_END - VOLUME_START) // VOLUME_STEP + 1))
stdevsArray = np.zeros(((DURATION_END - DURATION_START) // DURATION_STEP + 1, (VOLUME_END - VOLUME_START) // VOLUME_STEP + 1))

# Calcolo ma matrice delle velocità angolari in funzione di 
# durata e volume
duration = np.arange(DURATION_START, DURATION_END + DURATION_STEP, DURATION_STEP) #ms
duration = np.array([duration]).T
volume = np.arange(VOLUME_START, VOLUME_END + VOLUME_STEP, VOLUME_STEP) #ul
volume = np.array([volume])
flux = np.dot(1000 / duration, volume)
omega = flux / FLUX_TO_OMEGA

# Itero ogni file nella cartella
for graph in os.listdir():
	# Leggo il file
	with open(os.getcwd() + "/" + graph, mode='r') as f:
		textfile = f.read()
	
	# Estraggo i metadati dalla prima riga del file di testo
	metadata = get_metadata(textfile)
	textfile = textfile[textfile.index('\n')+1:]

	# Cambio il testo in modo tale da poter essere caricato direttamente
	# come lista e convertito in array di numpy
	data = convert_text_to_data(textfile)
	
	# Visto che Arduino non campiona precisamente a 1kHz mi calcolo la
	# vera frequenza di campionamento il rapporto tra il numero
	# di campioni effettivamente acquisiti e l'ultima registrazione
	# dei millisecondi
	trueSamplingRate, trueSamplingInterval = get_true_sampling_rate(data)
	
	# Calcolato l'intervallo di campionamento cambio la scala dei tempi
	# in maniera opportuna
	data = np.ndarray.astype(data, 'float64')
	data[:,0] = np.arange(1, len(data[:,0]) + 1) * trueSamplingInterval
	
	# Mi prendo tutti gli istanti di tempo in cui sono presenti gli step,
	# ed estraggo solo i primi, quindi i trigger, controllando quali
	# abbiano la distanza temporale dal precedente maggiore di un certo
	# valore regionevolmente grande, 1 s in questo caso
	triggerInstants, trueTriggerInstants = get_trigger_instants(data[:,2], trueSamplingInterval)
	
	# Filtro il segnale con kaiser
	fdata = filter_data(data[:,1], trueSamplingRate)

	# Prendo le basali di ogni epoca prendendo i 1000 campioni prima del trigger al
	# campione precedente ad esso
	# Suddivido inoltre il segnale in epoche, cioè da 500 campioni prima del trigger a 4500 dopo
	# Mi calcolo inoltre l'asse dei tempi delle epoche e converto le ordinate in Z-Score
	baselines, epochs, epochsAbscissa = get_epochs(fdata, triggerInstants, trueSamplingInterval)

	# Calcolo i ritardi ponendo una soglia pari a 5 Z-Score	
	# Calcolo anche media e deviazione standard dei ritardi e li inserisco
	# nella positione corretta dell'array iniziale
	delays, delaysMean, delaysStDev = calculate_delays(epochsAbscissa, epochs)
	meansArray[metadata[1] // DURATION_STEP - DURATION_ARRAYSHIFT, metadata[0] // VOLUME_STEP - VOLUME_ARRAYSHIFT] = delaysMean
	stdevsArray[metadata[1] // DURATION_STEP - DURATION_ARRAYSHIFT, metadata[0] // VOLUME_STEP - VOLUME_ARRAYSHIFT] = delaysStDev

# Calcolo matrice dei coefficienti di variazione
variationCoefficientArray = np.divide(stdevsArray, meansArray) * 100

# Per una questione grafica cambio i valori numeri delle coordinate
# di cui non si hanno dati
variationCoefficientArray[np.where(variationCoefficientArray == 0)] = 100
stdevsArray[np.where(stdevsArray == 0)] = np.max(stdevsArray)

# Trovo le coppie di valori per i quali si ha una bassa deviazione standard
# e le coordinate convertite per lo scatterplot
standardDeviationThreshold = 10
lowStDevs = np.where(stdevsArray <= standardDeviationThreshold)
lowStDevY = (lowStDevs[0] + DURATION_ARRAYSHIFT) * DURATION_STEP
lowStDevX = (lowStDevs[1] + VOLUME_ARRAYSHIFT) * VOLUME_STEP

# Trovo le coppie di valori per i quali si ha un'alta velocità angolare
# e le coordinate convertite per lo scatterplot
omegaThreshold = 1200
highOmega = np.where(omega >= omegaThreshold)
highOmegaY = (highOmega[0] + DURATION_ARRAYSHIFT) * DURATION_STEP
highOmegaX = (highOmega[1] + VOLUME_ARRAYSHIFT) * VOLUME_STEP

# Calcolo il range di coordinate dell'immagine
extent = (VOLUME_START - VOLUME_STEP // 2, VOLUME_END + VOLUME_STEP // 2, DURATION_END + DURATION_STEP // 2, DURATION_START - DURATION_STEP // 2)

matplotlib.rc('font', size=15)
matplotlib.rc('axes', titlepad=22)

plt.figure()
plt.title("Ritardo medio dello stimolo dal trigger")
plt.imshow(meansArray, cmap=cm.magma_r, extent=extent)
plt.xticks(range(VOLUME_START, VOLUME_END + VOLUME_STEP, VOLUME_STEP))
plt.yticks(range(DURATION_START, DURATION_END + DURATION_STEP, DURATION_STEP))
plt.xlabel("Volume (ul)")
plt.ylabel("Durata (ms)")
plt.colorbar(format='%d ms')
plt.scatter(highOmegaX, highOmegaY, s=160, c='red', marker='x', label='Velocità angolare elevata')
plt.scatter(300,500, s=170, c='red', marker='^', label='Risonanza troppo elevata')

plt.figure()
plt.title("Deviazione standard del ritardo dello stimolo dal trigger")
plt.imshow(stdevsArray, cmap=cm.magma_r, extent=extent)
plt.xticks(range(VOLUME_START, VOLUME_END + VOLUME_STEP, VOLUME_STEP))
plt.yticks(range(DURATION_START, DURATION_END + DURATION_STEP, DURATION_STEP))
plt.xlabel("Volume (ul)")
plt.ylabel("Durata (ms)")
plt.colorbar(format='%d ms')
plt.scatter(lowStDevX, lowStDevY, s=180, c='black', marker='*', label='Deviazione standard <= 10 ms')
plt.scatter(highOmegaX, highOmegaY, s=160, c='red', marker='x', label='Velocità angolare elevata')
plt.scatter(300,500, s=170, c='red', marker='^', label='Risonanza troppo elevata')

plt.figure()
plt.title("Coefficiente di variazione del ritardo dello stimolo dal trigger")
plt.imshow(variationCoefficientArray, cmap=cm.magma_r, extent=extent)
plt.xticks(range(VOLUME_START, VOLUME_END + VOLUME_STEP, VOLUME_STEP))
plt.yticks(range(DURATION_START, DURATION_END + DURATION_STEP, DURATION_STEP))
plt.xlabel("Volume (ul)")
plt.ylabel("Durata (ms)")
plt.colorbar(format='%d ms')
plt.scatter(lowStDevX, lowStDevY, s=180, c='black', marker='*', label='Deviazione standard <= 10 ms')
plt.scatter(highOmegaX, highOmegaY, s=160, c='red', marker='x', label='Velocità angolare elevata')
plt.scatter(300,500, s=170, c='red', marker='^', label='Risonanza troppo elevata')
#plt.legend(loc='best')

plt.show()

