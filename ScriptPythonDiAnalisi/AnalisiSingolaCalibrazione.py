# Analisi delle migliori calibrazioni
import sys
import numpy as np
import matplotlib
import matplotlib.pyplot as plt
import matplotlib.cm as cm
from FunzioniDiAnalisi import *

# Indici dei trial da scartare in ordine crescente
# È possibile che su 100 trial pochi ne escano rovinati per qualche motivi
# qui è possibile specificare quali sono da scartare
trialsToReject = [5, 68]

with open(sys.argv[1]) as f:
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
delays, delaysMean, delaysStDev = calculate_delays(epochsAbscissa, epochs, bad_trials=trialsToReject)

print("Media ritardo: %.2f" %delaysMean)
print("Dev. standard ritardo: %.2f" %delaysStDev)

maxV = np.max(data[:,1])
triggerPlot = [maxV if i in trueTriggerInstants else 0 for i in data[:,0]]

matplotlib.rc('font', size=15)
matplotlib.rc('axes', titlepad=22)

plt.figure()
plt.title("Andamento temporale della ddp a cavallo della resistenza di pull-down")
plt.xlabel("Istante (ms)")
plt.ylabel("Lettura a 10 bit")
plt.plot(data[:,0], data[:,1])
plt.plot(data[:,0], fdata)
plt.plot(data[:,0], triggerPlot)
plt.gca().spines['right'].set_visible(False)
plt.gca().spines['top'].set_visible(False)

plt.figure()
plt.title("Sovrapposzione delle epoche in unità di Z-Score")
colors = np.linspace(0.2, 1, len(epochs))
for index, epoch in enumerate(epochs):
	plt.plot(epochsAbscissa, epoch, c=(colors[index], 0, 0))
	plt.xlabel("Istante (ms)")
	plt.ylabel("Z-score")
plt.gca().spines['right'].set_visible(False)
plt.gca().spines['top'].set_visible(False)

plt.figure()
plt.title("Ritardi dei singoli trial")
plt.plot(range(len(delays)), delays)
plt.xlabel("Numero di prova")
plt.ylabel("Ritardo (ms)")
plt.gca().spines['right'].set_visible(False)
plt.gca().spines['top'].set_visible(False)
plt.draw()

plt.show()
