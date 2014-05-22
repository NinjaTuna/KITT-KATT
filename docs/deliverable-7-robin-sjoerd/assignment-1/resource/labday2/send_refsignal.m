function [y,x,x0] = send_refsignal(nrep,Fs,nchan)
% Test transmission using audio-beacon-like test signal, as generated by
% function 'refsgnal'.
% It is transmitted nrep times, result is in data vector y (2 columns if
% nchan = 2  microphones).
% 
% nrep: number of repetitions of pulse train
% Fs: sample frequency of the microphone receiver(s)
% nchan: number of microphones (1 or 2)
% 
% Output:
% y: recorded channel response to the transmit sequence (nrep repetitions)
% x: transmit sequence (1 repetition)
% x0: unmodulated transmit sequence (1 repetition), i.e., Timer0 not used
%     x0 is truncated to its nonzero part only.

% defaults if not specified:
if nargin < 3,
    nchan = 1;
end
if nargin < 2,
    Fs = 44100;
end
if nargin < 1,
    nrep = 3;
end

%----------------------------------------------------------
% set up transmit signal
Fs_TX = 44100;			% set transmitter sample rate (Hz)

Nbits = 32;
Timer0 = 1;
Timer1 = 0;
Timer3 = 2;
code = '92340f0faaaa4321';

x = refsignal(Nbits, Timer0,Timer1,Timer3,code,Fs_TX);	 % ref signal

[x0,last] = refsignal(Nbits,-1,Timer1,Timer3,code,Fs_TX);% unmodulated signal
x0 = x0(1:last);		% truncate to the nonzero part

% now repeat the transmit signal nrep times
xx = kron(ones(nrep,1), x);	% nrep times copied signal x

Trec = length(xx)/Fs_TX;	% duration of transmission in seconds


%----------------------------------------------------------
% set up receiver
% Fs = 44100;			% set receiver sample rate (Hz)// use input var
r = audiorecorder(Fs, 16, nchan);

%----------------------------------------------------------
% make transmission and do recording
y = audioplayer(xx,Fs_TX);	% convert signal to audio format ready to play

record(r,Trec);			% switch on nonblocking recording

play(y)				% play and continue directly
pause(Trec);			% pause until playing finishes

stop(r)				% close recording file so it can be read

%----------------------------------------------------------
% generate output vector (or matrix)
y = getaudiodata(r);		% convert recording; 2 columns = 2 mic signals
