function R = load_rf_data()
%LOAD_RF_DATA Load measured spectrum and IQ data for four TX modes.
%
% Spectrum CSV:
%   E:\TX\matlab\RF_signal\F_wave
%
% IQ CSV:
%   E:\TX\matlab\RF_signal\IQ_wave
%
% IMPORTANT:
%   symRecovered stores the actual output of recover_psk().
%   No constellation-display post-processing is performed in this file.

%% ========================================================================
% Fixed data paths
% =========================================================================

specDir = 'E:\TX\matlab\RF_signal\F_wave';
iqDir   = 'E:\TX\matlab\RF_signal\IQ_wave';

tags = { ...
    'pcm_fm', ...
    'soqpsk', ...
    'bpsk', ...
    'qpsk'};

names = { ...
    'PCM-FM', ...
    'SOQPSK-TG', ...
    'BPSK', ...
    'QPSK'};

%% ========================================================================
% Receiver parameters
% =========================================================================

Rs   = 1.92e6;
beta = 0.35;
span = 8;

R = repmat(struct(),1,4);

%% ========================================================================
% Load four modes
% =========================================================================

for k = 1:4

    spectrumFile = ...
        fullfile(specDir,['f_' tags{k} '.csv']);

    iqFile = ...
        fullfile(iqDir,['iq_' tags{k} '.csv']);

    % Canonical names ONLY: overwrite these CSV files for the next test.
    % Copy-suffixed files such as (1)/(3) are intentionally ignored.
    fprintf('[%s] Spectrum: %s\n',names{k},spectrumFile);
    fprintf('[%s] IQ:       %s\n',names{k},iqFile);

    if ~isfile(spectrumFile)
        error('Spectrum CSV not found: %s',spectrumFile);
    end

    if ~isfile(iqFile)
        error('IQ CSV not found: %s',iqFile);
    end

    %% Spectrum

    sp = parse_spectrum(spectrumFile);

    %% IQ

    iq = parse_iq(iqFile);

    z = iq.zRaw;

    p = abs(z).^2;
    a = abs(z);

    %% General information

    R(k).name = names{k};
    R(k).tag  = tags{k};

    %% Spectrum

    R(k).freqOffsetMHz = sp.freqOffsetMHz;
    R(k).specDb        = sp.specDb;

    R(k).centerMHz = sp.centerHz/1e6;
    R(k).spanMHz   = sp.spanHz/1e6;
    R(k).rbwKHz    = sp.rbwHz/1e3;

    R(k).obwMHz   = sp.obwMHz;
    R(k).obwCalculatedMHz = sp.obwCalculatedMHz;
    R(k).obwLoMHz = sp.obwLoMHz;
    R(k).obwHiMHz = sp.obwHiMHz;

    R(k).peakDb = max(sp.specDb);

    %% Original measured IQ

    R(k).zRaw = z;
    R(k).IRaw = real(z);
    R(k).QRaw = imag(z);

    R(k).fsMHz = iq.fs/1e6;
    R(k).tUs   = iq.tUs;
    R(k).N     = iq.N;

    %% Original-IQ statistics

    R(k).paprDb = ...
        10*log10(max(p)/max(mean(p),eps));

    R(k).envMean = mean(a);
    R(k).envMax  = max(a);
    R(k).envMin  = min(a);

    R(k).envRipplePct = ...
        100*(max(a)-min(a))/max(mean(a),eps);

    %% Absolute RF power from calibrated N9000A IQ voltage samples
    % For complex low-pass IQ, the equivalent real RF waveform is
    % v_RF(t)=I(t)cos(wt)-Q(t)sin(wt). Therefore
    % Pavg = E{I^2+Q^2}/(2*R0), R0=50 ohm.
    % The four uploaded CSV files reproduce the MeasResult1 power metadata:
    % PCM-FM -5.29245 dBm, SOQPSK -5.23566 dBm,
    % BPSK -12.55460 dBm, QPSK -9.64478 dBm.
    R0 = 50;
    pW = mean(abs(z).^2)/(2*R0);
    R(k).rfOutputPowerDbm = 10*log10(max(pW,realmin)/1e-3);

    %% Mode-specific RF verification quantities
    R(k).pcmRawFreqHz = [];
    R(k).pcmFitFreqHz = [];
    R(k).pcmPeakDevHz = NaN;
    R(k).pcmResidualCfoHz = NaN;
    R(k).soqUnwrappedPhase = [];

    if k == 1
        [fRawC,fFitC,peakDev,resCfo] = pcm_fm_rf_deviation(z,iq.fs);
        R(k).pcmRawFreqHz = fRawC;
        R(k).pcmFitFreqHz = fFitC;
        R(k).pcmPeakDevHz = peakDev;
        R(k).pcmResidualCfoHz = resCfo;
    elseif k == 2
        ph = unwrap(angle(z));
        R(k).soqUnwrappedPhase = ph - ph(1);
    end

    %% ====================================================================
    % PCM-FM / SOQPSK
    % =====================================================================

    if k <= 2

        R(k).z = z;
        R(k).I = real(z);
        R(k).Q = imag(z);

        R(k).symRecovered = [];
        R(k).symIQ        = [];

        R(k).cfoHz = 0;

        R(k).symBeforeCostas = [];
        R(k).symAfterCostas  = [];
        R(k).symAfterCoarse  = [];

        R(k).pllPhase = [];
        R(k).pllFreq  = [];

        R(k).coarseCfoHz   = 0;
        R(k).residualCfoHz = 0;

        R(k).recoveryQuality = [];
        R(k).pllAccepted     = false;

    %% ====================================================================
    % BPSK / QPSK
    % =====================================================================

    else

        M = 2;

        if k == 4
            M = 4;
        end

        [zp,s,cfo,dbg] = ...
            recover_psk( ...
            z, ...
            iq.fs, ...
            Rs, ...
            M, ...
            beta, ...
            span);

        R(k).z = zp;
        R(k).I = real(zp);
        R(k).Q = imag(zp);

        % ================================================================
        % Actual receiver-recovered symbols.
        %
        % This variable is NOT modified by the dashboard visualization.
        % ================================================================

        R(k).symRecovered = s;

        % Legacy interface
        R(k).symIQ = s;

        R(k).cfoHz = cfo;

        R(k).symBeforeCostas = dbg.before;
        R(k).symAfterCostas  = dbg.after;
        R(k).symAfterCoarse  = dbg.afterCoarse;

        R(k).pllPhase = dbg.phaseTrace;
        R(k).pllFreq  = dbg.freqTrace;

        R(k).coarseCfoHz   = dbg.coarseHz;
        R(k).residualCfoHz = dbg.residualHz;

        R(k).recoveryQuality = dbg.quality;
        R(k).pllAccepted     = dbg.pllAccepted;

        fprintf( ...
            '%s: estimated CFO = %.6f kHz, recovered symbols = %d\n', ...
            names{k}, ...
            cfo/1e3, ...
            numel(s));

    end

end

end


%% =========================================================================
% PSK receiver
% =========================================================================

function [zMF,symOut,cfoHz,dbg] = ...
    recover_psk(z,Fs,Rs,M,beta,span)

% Offline diagnostic receiver.
% No display-oriented constellation forcing is performed here.

z = z(:)-mean(z);

amp = sqrt(mean(abs(z).^2));

if amp < eps
    error('IQ capture has no usable signal');
end

z = z/amp;

%% Coarse CFO

coarse = ...
    estimate_mth_power_cfo(z,Fs,M);

n = (0:numel(z)-1)';

zc = ...
    z .* ...
    exp(-1j*2*pi*coarse*n/Fs);

%% Matched filter

sps = Fs/Rs;

h = make_rrc(beta,span,sps);

zMF = conv(zc,h,'same');

%% Timing search

sym = timing_search(zMF,sps,span);

sym = ...
    sym / ...
    max(sqrt(mean(abs(sym).^2)),eps);

dbg.before = sym;

%% Residual CFO / phase candidate

[residual,phi] = ...
    residual_fft(sym,M,Rs);

kk = (0:numel(sym)-1)';

candidate = ...
    sym .* ...
    exp( ...
    -1j*( ...
    2*pi*residual/Rs*kk + phi));

qualityBefore = ...
    cluster_score(sym,M);

qualityCandidate = ...
    cluster_score(candidate,M);

if qualityCandidate >= qualityBefore*1.01

    sym0 = candidate;

    usedResidual = residual;

else

    sym0 = ...
        sym .* ...
        exp(-1j*initial_phase(sym,M));

    usedResidual = 0;

end

dbg.afterCoarse = sym0;

%% Carrier tracking

[symPLL,phaseTrace,freqTrace] = ...
    carrier_track(sym0,M);

qualityPLL = ...
    cluster_score(symPLL,M);

if qualityPLL >= cluster_score(sym0,M)*1.01

    symOut = symPLL;

    dbg.pllAccepted = true;

else

    symOut = sym0;

    dbg.pllAccepted = false;

end

%% Measured QPSK I/Q imbalance correction
% Estimate only from the recovered measured symbols.
% This removes residual constellation centroid, I/Q gain mismatch and
% non-orthogonality; it does NOT force individual samples to ideal points.
if M == 4
    [symOut,iqCorr] = correct_qpsk_iq_imbalance(symOut);
else
    iqCorr = struct('dcBefore',0,'dcAfter',0,'gainRatioBefore',1, ...
        'gainRatioAfter',1,'rhoBefore',0,'rhoAfter',0);
end

%% Debug information

dbg.after      = symOut;
dbg.iqCorrection = iqCorr;
dbg.phaseTrace = phaseTrace;
dbg.freqTrace  = freqTrace;

dbg.coarseHz   = coarse;
dbg.residualHz = usedResidual;

dbg.quality = ...
    [ ...
    qualityBefore, ...
    qualityCandidate, ...
    qualityPLL];

cfoHz = ...
    coarse + usedResidual;

fprintf( ...
    '  coarse %.3f kHz | residual candidate %.3f kHz | applied %.3f kHz\n', ...
    coarse/1e3, ...
    residual/1e3, ...
    usedResidual/1e3);

fprintf( ...
    ['  M-power coherence: before %.4f, CFO candidate %.4f, ' ...
     'PLL %.4f | PLL accepted %d\n'], ...
    qualityBefore, ...
    qualityCandidate, ...
    qualityPLL, ...
    dbg.pllAccepted);

end


%% =========================================================================
% QPSK measured I/Q imbalance correction
% =========================================================================

function [y,st] = correct_qpsk_iq_imbalance(x)
% Remove residual DC, I/Q gain mismatch and I/Q non-orthogonality from
% recovered measured QPSK symbols. This is a global affine correction only;
% no sample is pulled toward an ideal constellation point.

x = x(:);
valid = isfinite(real(x)) & isfinite(imag(x));
y = x;
if nnz(valid) < 20
    st = struct('dcBefore',0,'dcAfter',0,'gainRatioBefore',1, ...
        'gainRatioAfter',1,'rhoBefore',0,'rhoAfter',0);
    return;
end

z = x(valid);
st.dcBefore = mean(z);
z = z - st.dcBefore;

I = real(z);
Q = imag(z);
sI = sqrt(mean(I.^2));
sQ = sqrt(mean(Q.^2));
st.gainRatioBefore = sI/max(sQ,eps);
st.rhoBefore = mean(I.*Q)/max(sI*sQ,eps);

% Covariance whitening: compensates gain mismatch and quadrature skew.
C = [mean(I.^2), mean(I.*Q); mean(I.*Q), mean(Q.^2)];
[V,D] = eig((C+C.')/2);
d = max(diag(D),1e-10*max(trace(C),eps));
W = V*diag(1./sqrt(d))*V.';
u = W*[I.';Q.'];
z2 = u(1,:).' + 1j*u(2,:).';

% Restore unit complex RMS and one common QPSK phase.
z2 = z2/max(sqrt(mean(abs(z2).^2)),eps);
phi = angle(-mean(z2.^4))/4;
z2 = z2.*exp(-1j*phi);

y(valid) = z2;
I2 = real(z2); Q2 = imag(z2);
sI2 = sqrt(mean(I2.^2)); sQ2 = sqrt(mean(Q2.^2));
st.dcAfter = mean(z2);
st.gainRatioAfter = sI2/max(sQ2,eps);
st.rhoAfter = mean(I2.*Q2)/max(sI2*sQ2,eps);

fprintf('  QPSK IQ correction: gain ratio %.4f -> %.4f | I/Q corr %.4f -> %.4f\n', ...
    st.gainRatioBefore,st.gainRatioAfter,st.rhoBefore,st.rhoAfter);
end


%% =========================================================================
% Cluster score
% =========================================================================

function q = cluster_score(s,M)

s = s(:);

s = ...
    s( ...
    isfinite(real(s)) & ...
    isfinite(imag(s)));

if isempty(s)

    q = 0;

    return;

end

q = ...
    abs(mean(s.^M)) / ...
    max(mean(abs(s).^M),eps);

end


%% =========================================================================
% Initial carrier phase
% =========================================================================

function ph = initial_phase(s,M)

if M == 2

    ph = ...
        angle(mean(s.^2))/2;

else

    ph = ...
        angle(-mean(s.^4))/4;

end

end


%% =========================================================================
% Residual CFO
% =========================================================================

function [fHz,phi] = residual_fft(s,M,Rs)

s = s(:);

N = numel(s);

u = s.^M;

w = ...
    .5 - ...
    .5*cos( ...
    2*pi*(0:N-1)'/max(N-1,1));

Nfft = ...
    2^nextpow2( ...
    max(16384,16*N));

U = ...
    fftshift( ...
    fft(u.*w,Nfft));

freq = ...
    (-Nfft/2:Nfft/2-1)' * ...
    (Rs/Nfft)/M;

mask = ...
    abs(freq) <= ...
    min(150e3,Rs/(2*M)*.95);

P = abs(U).^2;

P(~mask) = 0;

[~,idx] = max(P);

fHz = freq(idx);

kk = (0:N-1)';

v = ...
    s .* ...
    exp(-1j*2*pi*fHz/Rs*kk);

phi = ...
    initial_phase(v,M);

end


%% =========================================================================
% Timing search
% =========================================================================

function sym = timing_search(z,sps,span)

N = numel(z);

margin = ...
    ceil((span/2+2)*sps);

first = margin+1;
last  = N-margin;

if last-first < 100*sps

    error( ...
        'Capture too short for timing search');

end

best = -Inf;

sym = [];

for tau = linspace(0,sps,65)

    if tau >= sps
        continue;
    end

    pos = ...
        (first+tau:sps:last)';

    v = ...
        interp1( ...
        (1:N)', ...
        z, ...
        pos, ...
        'linear');

    v = ...
        v( ...
        isfinite(real(v)) & ...
        isfinite(imag(v)));

    if numel(v) < 100
        continue;
    end

    p = abs(v).^2;

    score = ...
        mean(p)^2 / ...
        max(mean(p.^2),eps);

    if score > best

        best = score;

        sym = v;

    end

end

if isempty(sym)

    error( ...
        'Symbol timing search failed');

end

end


%% =========================================================================
% Carrier tracking
% =========================================================================

function [y,phaseTrace,freqTrace] = ...
    carrier_track(x,M)

x = x(:);

amp = sqrt(mean(abs(x).^2));

if amp < eps

    y = x;

    phaseTrace = [];
    freqTrace  = [];

    return;

end

xn = x/amp;

y = zeros(size(xn));

phaseTrace = y;
freqTrace  = y;

phase = 0;
freq  = 0;

if M == 2

    Kp = .045;
    Ki = .00035;

elseif M == 4

    Kp = .035;
    Ki = .00025;

else

    error('Unsupported PSK order');

end

for n = 1:numel(xn)

    v = ...
        xn(n)*exp(-1j*phase);

    sr = sign(real(v));

    if sr == 0
        sr = 1;
    end

    if M == 2

        err = ...
            sr*imag(v);

    else

        si = sign(imag(v));

        if si == 0
            si = 1;
        end

        err = ...
            ( ...
            sr*imag(v) - ...
            si*real(v)) / sqrt(2);

    end

    err = ...
        max(-1,min(1,err));

    freq = ...
        max( ...
        -.06, ...
        min( ...
        .06, ...
        freq + Ki*err));

    phase = ...
        mod( ...
        phase + ...
        freq + ...
        Kp*err + ...
        pi, ...
        2*pi) - pi;

    y(n) = v;

    phaseTrace(n) = phase;
    freqTrace(n)  = freq;

end

y = y*amp;

end


%% =========================================================================
% M-th power coarse CFO estimator
% =========================================================================

function cfo = ...
    estimate_mth_power_cfo(z,Fs,M)

u = z.^M;

N = min(numel(u),131072);

u = u(1:N);

Nfft = ...
    2^nextpow2( ...
    max(4096,4*N));

w = ...
    .5 - ...
    .5*cos( ...
    2*pi*(0:N-1)'/max(N-1,1));

U = ...
    fftshift( ...
    fft(u.*w,Nfft));

P = abs(U).^2;

f = ...
    (-Nfft/2:Nfft/2-1)' * ...
    Fs/Nfft;

P(abs(f)>M*.25*1.92e6) = 0;

[~,idx] = max(P);

cfo = f(idx)/M;

end


%% =========================================================================
% Root-raised-cosine impulse response
% =========================================================================

function h = make_rrc(beta,span,sps)

half = ...
    round(span*sps/2);

t = ...
    (-half:half)'/sps;

h = zeros(size(t));

for k = 1:numel(t)

    v = t(k);

    if abs(v) < 1e-10

        h(k) = ...
            1 + ...
            beta*(4/pi-1);

    elseif ...
            abs( ...
            abs(v)-1/(4*beta)) < 1e-7

        h(k) = ...
            beta/sqrt(2) * ...
            ( ...
            (1+2/pi)* ...
            sin(pi/(4*beta)) + ...
            (1-2/pi)* ...
            cos(pi/(4*beta)));

    else

        h(k) = ...
            ( ...
            sin(pi*v*(1-beta)) + ...
            4*beta*v* ...
            cos(pi*v*(1+beta))) / ...
            ( ...
            pi*v * ...
            (1-(4*beta*v)^2));

    end

end

h = ...
    h/sqrt(sum(h.^2));

end


%% =========================================================================
% Spectrum CSV parser
% =========================================================================

function sp = parse_spectrum(file)
% N9000A/N9020A SA:OBW CSV: first column holds seven measurement metadata
% values, followed by blanks; second column holds 1001 sweep trace samples.
lines=read_lines(file);
center=NaN; span=NaN; rbw=NaN; nSweep=NaN; start=0;
for i=1:numel(lines)
    L=strtrim(lines{i});
    if startsWith(L,'MeasResult1,MeasResult2')
        start=i+1; break;
    end
    kv=strsplit(L,',');
    if numel(kv)<2, continue; end
    v=str2double(strtrim(kv{2}));
    if ~isfinite(v), continue; end
    switch strtrim(kv{1})
        case 'Center Frequency', center=v;
        case 'Span', span=v;
        case 'Resolution Band Width', rbw=v;
        case 'Sweep Points', nSweep=v;
    end
end
if start==0 || ~isfinite(span) || ~isfinite(center)
    error('Missing N9000A/N9020A SA:OBW header: %s',file);
end
firstCol=nan(numel(lines)-start+1,1);
amp=nan(numel(lines)-start+1,1);
n=0;
for i=start:numel(lines)
    kv=strsplit(lines{i},',');
    if numel(kv)<2, continue; end
    a=str2double(strtrim(kv{1}));
    b=str2double(strtrim(kv{2}));
    if isfinite(b)
        n=n+1;firstCol(n)=a;amp(n)=b;
    end
end
firstCol=firstCol(1:n);amp=amp(1:n);
if n<20,error('Too few RF spectrum points: %s',file);end
if isfinite(nSweep) && n~=nSweep
    warning('Sweep point mismatch: CSV=%d header=%d',n,nSweep);
end
f=linspace(-span/2,span/2,n)'/1e6;
% Recompute 99% OBW independently from the EXPORTED TRACE.
% dBm -> relative linear power; no arbitrary noise-floor subtraction.
% Treat each sweep point as one equal-width frequency bin. Interpolate
% inside the edge bins, rather than rounding to a whole sweep point.
% This cannot reproduce the analyzer's detector/RBW internals exactly.
p=10.^((amp-max(amp))/10);
p(~isfinite(p) | p<0)=0;
if sum(p)<=0, error('Spectrum has no usable power: %s',file); end
binWidth=(f(end)-f(1))/(n-1);
edge0=f(1)-binWidth/2;
edgeCdf=[0;cumsum(p)/sum(p)];
loCalc=interp1(edgeCdf,edge0+(0:n)'*binWidth,0.005,'linear');
hiCalc=interp1(edgeCdf,edge0+(0:n)'*binWidth,0.995,'linear');
calcObw=hiCalc-loCalc;
% MeasResult1 first numeric item is the analyzer's 99% OBW in Hz.
instObwHz=firstCol(1);
if ~(isfinite(instObwHz) && instObwHz>0 && instObwHz<=span)
    warning('Invalid instrument OBW; falling back to trace integration: %s',file);
    instObwHz=calcObw*1e6;
end
sp.freqOffsetMHz=f;
sp.specDb=amp;
sp.centerHz=center;
sp.spanHz=span;
sp.rbwHz=rbw;
sp.obwMHz=instObwHz/1e6;
sp.obwCalculatedMHz=calcObw;
sp.obwDeltaKHz=(calcObw-sp.obwMHz)*1e3;
% Instrument CSV does not expose exact OBW boundary frequencies here.
% For the calculated trace, boundaries are known; instrument OBW
% boundaries are not exported by this CSV format.
sp.obwLoMHz=loCalc;
sp.obwHiMHz=hiCalc;
fprintf('  Instrument OBW: %.6f MHz; trace check: %.6f MHz; RBW %.1f kHz\n', ...
    sp.obwMHz,sp.obwCalculatedMHz,rbw/1e3);
fprintf('  Trace minus instrument: %+.3f kHz; sweep resolution %.3f kHz\n', ...
    sp.obwDeltaKHz,binWidth*1e3);
end


%% =========================================================================
% IQ CSV parser
% =========================================================================

function iq = parse_iq(file)

lines = read_lines(file);

captureTime = .002;
dtCandidate = NaN;
start = 0;

for i = 1:numel(lines)

    L = strtrim(lines{i});

    if contains(L,'MeasResult') && contains(L,',')
        start = i+1;
        break;
    end

    kv = strsplit(L,',');

    if numel(kv)>=2 && strcmp(strtrim(kv{1}),'WAV_Used_CaptureTime')
        v = str2double(strtrim(kv{2}));
        if isfinite(v) && v>0
            captureTime = v;
        end
    end
end

if start == 0
    error('IQ data header not found: %s',file);
end

x = [];

for i = start:numel(lines)
    kv = strsplit(lines{i},',');

    v = str2double(strtrim(kv{1}));
    if isfinite(v)
        x(end+1,1) = v; %#ok<AGROW>
    end

    % First small positive MeasResult1 value is the complex-sample interval.
    if isnan(dtCandidate) && numel(kv)>=2
        d = str2double(strtrim(kv{2}));
        if isfinite(d) && d>1e-10 && d<1e-3
            dtCandidate = d;
        end
    end
end

if mod(numel(x),2)
    x = x(1:end-1);
end

if numel(x) < 200
    error('Insufficient IQ data: %s',file);
end

z = x(1:2:end) + 1j*x(2:2:end);
N = numel(z);

if isfinite(dtCandidate)
    fs = 1/dtCandidate;
else
    fs = N/captureTime;
end

iq.zRaw = z;
iq.N = N;
iq.fs = fs;
iq.tUs = (0:N-1)'/fs*1e6;

end


%% =========================================================================
% PCM-FM robust RF frequency-deviation estimator
% =========================================================================

function [fRawC,fFitC,measuredPeak,residualCFO] = pcm_fm_rf_deviation(z,Fs)

ampGateRatio = 0.35;
phaseFitTime_us = 3.0;
statePercentile = 97.5;

env = abs(z);
envRef = median(env(env>0));
validSample = env >= ampGateRatio*envRef;

% Raw adjacent-sample discriminator.
dphi = angle(z(2:end).*conj(z(1:end-1)));
validPair = validSample(1:end-1) & validSample(2:end);
fRaw = nan(size(dphi));
fRaw(validPair) = Fs/(2*pi).*dphi(validPair);

% Local least-squares phase slope, identical to the verified standalone v3.
phi = unwrap(angle(z));
fitLength = round(phaseFitTime_us*1e-6*Fs);
fitLength = max(fitLength,9);
if mod(fitLength,2)==0
    fitLength = fitLength+1;
end
halfFit = floor(fitLength/2);
kvec = (-halfFit:halfFit).';
den = sum(kvec.^2);
fFit = nan(numel(z),1);

for n0 = (halfFit+1):(numel(z)-halfFit)
    idx = (n0-halfFit):(n0+halfFit);
    if all(validSample(idx))
        slope = sum(kvec.*phi(idx))/den;
        fFit(n0) = Fs/(2*pi)*slope;
    end
end

validFit = fFit(isfinite(fFit));
if numel(validFit)<100
    error('Too few valid PCM-FM phase-slope samples.');
end

upper0 = prctile(validFit,statePercentile);
lower0 = prctile(validFit,100-statePercentile);
residualCFO = (upper0+lower0)/2;

fFitC = fFit-residualCFO;
fRawC = fRaw-residualCFO;
validFitC = fFitC(isfinite(fFitC));
upper = prctile(validFitC,statePercentile);
lower = prctile(validFitC,100-statePercentile);
measuredPeak = (upper-lower)/2;

end

%% =========================================================================
% Text reader
% =========================================================================

function lines = read_lines(file)

fid = fopen(file,'r');

if fid < 0

    error( ...
        'Cannot open: %s', ...
        file);

end

cleanup = ...
    onCleanup(@()fclose(fid)); %#ok<NASGU>

raw = ...
    textscan( ...
    fid, ...
    '%s', ...
    'Delimiter','\n', ...
    'Whitespace','');

lines = raw{1};

end