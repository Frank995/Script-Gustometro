# File contenente le funzioni usate per l'analisi dei file di calibrazione
import numpy as np
import scipy.signal as sig
from json import loads
from statistics import mean, stdev

# Funzione trovata online per calcolare a quali ascisse un vettore di dati
# supera una certa soglia
def find_transition_times(t, y, threshold):
    """
    Given the input signal `y` with samples at times `t`,
    find the times where `y` increases through the value `threshold`.

    `t` and `y` must be 1-D numpy arrays.

    Linear interpolation is used to estimate the time `t` between
    samples at which the transitions occur.
    """
	
    # Find where y crosses the threshold (increasing).
    lower = y < threshold
    higher = y >= threshold
    transition_indices = np.where(lower[:-1] & higher[1:])[0]
	
    # Linearly interpolate the time values where the transition occurs.
    t0 = t[transition_indices]
    t1 = t[transition_indices + 1]
    y0 = y[transition_indices]
    y1 = y[transition_indices + 1]
    slope = (y1 - y0) / (t1 - t0)
    transition_times = t0 + (threshold - y0) / slope
	
    return transition_times

# Estraggo i metadati dalla prima riga del file di testo
def get_metadata(textfile):
	metadata = textfile[:textfile.index('\n')]
	metadata = tuple(int(float(data.split(': ')[1])) for data in metadata.split(',   '))
	
	return metadata

# Converto il file di testo in modo da essere interpretabile come array
def convert_text_to_data(textfile):
	textfile = '[[' + textfile.replace('\t',',').replace('\n','],[')[:-3] + ']]'
	data = np.array(loads(textfile))

	return data

# Calcolo la vera frequenza di campionamento
def get_true_sampling_rate(data):
	trueSamplingRate = len(data) / data[-1][0]
	trueSamplingInterval = round(1 / trueSamplingRate, 3) # ms
	trueSamplingRate = round(trueSamplingRate * 1000, 3) # Hz

	return trueSamplingRate, trueSamplingInterval

# Calcolo gli istanti di trigger a partire dagli istanti di step
# eliminando i primi due che sono generalmente più "sporchi"
# dei successivi
def get_trigger_instants(steps, samplingInterval):
	stepUpInstants = np.flatnonzero(steps == 1023)
	triggerInstants = [stepUpInstants[0]] + [stepUpInstants[i] for i in range(len(stepUpInstants)) if stepUpInstants[i] - stepUpInstants[i-1] >= 1000]
	triggerInstants = np.array(triggerInstants[2:])
	trueTriggerInstants = (triggerInstants + 1) * samplingInterval

	return triggerInstants, trueTriggerInstants

# Filtro i dati
def filter_data(data, fs, attenuation = 60, cutoff = 50, transitionWidth = 5):
	nyquistF = fs / 2
	transitionBand = transitionWidth / nyquistF
	numtaps, beta = sig.kaiserord(attenuation, transitionBand)
	taps = sig.firwin(numtaps, cutoff, window=('kaiser', beta), scale=False, nyq=nyquistF)
	fdata = sig.lfilter(taps, 1.0, data)

	# Il segnale risulta ritardato a causa del filtro quindi lo traslo
	# indietro per farlo coincidere, e riempio di zeri gli ultimi campioni
	# vuoti
	toShift = numtaps // 2
	fdata = np.concatenate((fdata[toShift:],np.zeros(toShift)))

	return fdata

# Prendo le baseline, epoche e le ascisse delle epoche
def get_epochs(data, triggerInstants, samplingInterval, baselinelength=1000, epochstart=-500, epochend=4500):
	baselines = np.array([data[trigger-baselinelength:trigger] for trigger in triggerInstants])

	epochs = np.array([data[trigger+epochstart:trigger+epochend] for trigger in triggerInstants])
	epochs = np.array([(epochs[i] - mean(baselines[i])) / stdev(baselines[i]) for i in range(len(triggerInstants))])

	epochsAbscissa = np.array(tuple(range(epochstart,epochend))) * samplingInterval
	
	return baselines, epochs, epochsAbscissa

# Calcolo le informazioni sul ritardo
def calculate_delays(epochsAbscissa, epochs, bad_trials=[], threshold=5):
	delays = [find_transition_times(epochsAbscissa, epoch, threshold)[0] for epoch in epochs]
	bad_trials.reverse()
	for trial in bad_trials:
		try:
			del delays[trial]
		except:
			pass

	delaysMean = mean(delays)
	delaysStDev = stdev(delays)

	return delays, delaysMean, delaysStDev
