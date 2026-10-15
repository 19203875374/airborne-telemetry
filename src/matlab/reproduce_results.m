function reproduce_results(workRoot, sourceKind)
% One-shot static export; no timers or automatic dashboard refresh.
% Calls the archived measured-IQ recovery chain without algorithm changes.
if nargin < 2, sourceKind = 'archived'; end
assert(any(strcmp(sourceKind,{'archived','new'})), 'sourceKind must be archived or new');
workRoot = char(workRoot);
outDir = fullfile(workRoot,'output','matlab');
if ~isfolder(outDir), mkdir(outDir); end
diary(fullfile(outDir,'matlab_reproduction.log'));
cleanupDiary = onCleanup(@()diary('off')); %#ok<NASGU>
disp(version); ver;
if strcmp(sourceKind,'archived'), dataFolder = 'baseband_archived'; else, dataFolder = 'baseband'; end
iqFile = fullfile(workRoot,'data',dataFolder,'pcm_net_mode_switch_iq.txt');
opts = detectImportOptions(iqFile,'FileType','text');
opts.Delimiter = {' ',sprintf('\t')};
opts.ConsecutiveDelimitersRule = 'join';
T = readtable(iqFile,opts);
assert(all(ismember({'sample','active_mode','i','q'},T.Properties.VariableNames)), 'Unexpected columns');
Fs = 30.72e6;
tags = {'pcm_fm','soqpsk','bpsk','qpsk'};
names = {'PCM-FM','SOQPSK-TG','BPSK','QPSK'};
stats = zeros(4,3);
for m = 0:3
    ix = find(T.active_mode == m);
    assert(~isempty(ix),'Mode missing');
    cut = [0; find(diff(T.sample(ix)) ~= 1); numel(ix)];
    [~,j] = max(diff(cut));
    ix = ix(cut(j)+1:cut(j+1));
    z = double(T.i(ix)) + 1j*double(T.q(ix));
    nz = find(abs(z)>0);
    assert(~isempty(nz),'All-zero mode');
    z = z(nz(1):nz(end));
    p = abs(z).^2;
    papr = 10*log10(max(p)/mean(p));
    stats(m+1,:) = [numel(z),Fs/1e6,papr];
    f = figure('Visible','off','Color','w','Position',[100 100 1000 700]);
    closeFig = onCleanup(@()close(f));
    n = min(numel(z),4096); q = z(1:n);
    subplot(2,2,1); plot((0:n-1)'/Fs*1e6,[real(q),imag(q)]); grid on;
    xlabel('Time (us)'); ylabel('RTL amplitude'); title([names{m+1} ' I/Q']);
    subplot(2,2,2); plot(real(q),imag(q),'.'); axis equal; grid on;
    xlabel('I');ylabel('Q');title('Raw RTL I/Q trajectory');
    subplot(2,2,3); plot((0:n-1)'/Fs*1e6,unwrap(angle(q)));grid on;
    xlabel('Time (us)');ylabel('Phase (rad)');title('Unwrapped sample phase');
    NFFT=16384; h=0.5-0.5*cos(2*pi*(0:n-1)'/max(n-1,1));
    P=abs(fftshift(fft((q-mean(q)).*h,NFFT))).^2;
    subplot(2,2,4);plot((-NFFT/2:NFFT/2-1)'/NFFT*Fs/1e6,10*log10(max(P,eps)/max(P)));grid on;
    xlabel('Baseband offset (MHz)');ylabel('Relative power (dB)');title('Single-window spectrum, not OBW verdict');
    saveas(f,fullfile(outDir,['baseband_' tags{m+1} '.png']));
    clear closeFig;
end
S=table(names',stats(:,1),stats(:,2),stats(:,3), ...
    'VariableNames',{'Mode','SelectedSamples','FsMHz','PAPR_dB'});
writetable(S,fullfile(outDir,['baseband_' sourceKind '_summary.csv']));
disp(S);
addpath(fullfile(workRoot,'matlab_rf'));
clear load_rf_data;
which load_rf_data -all;
R=load_rf_data();
save(fullfile(outDir,'rf_recovery.mat'),'R','-v7.3');
RS=table({R.name}',[R.N]',[R.fsMHz]',[R.paprDb]',[R.obwMHz]', ...
    'VariableNames',{'Mode','Samples','FsMHz','PAPR_dB','InstrumentOBW_MHz'});
writetable(RS,fullfile(outDir,'rf_summary.csv'));
disp(RS);
for k=1:4
    f=figure('Visible','off','Color','w');
    closeFig=onCleanup(@()close(f));
    if k<=2
        z=R(k).zRaw; lab='Measured RF I/Q trajectory';
    else
        z=R(k).symRecovered; lab='Recovered pre-decision symbols';
    end
    z=z(1:min(numel(z),12000));
    plot(real(z),imag(z),'.');axis equal;grid on;xlabel('I');ylabel('Q');
    title([names{k} ' - ' lab]);
    saveas(f,fullfile(outDir,['rf_' tags{k} '.png']));
    clear closeFig;
end
fprintf('Static reproduction finished: %s\n',outDir);
end
