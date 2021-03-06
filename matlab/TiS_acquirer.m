%% start attuator (zaber) controller
z   = Zaber.Controller;

% commands are (usually ID=2)
% z.move_absolute(ID, position_in_mm, 'mm')
% z.move_relative(ID, position_in_mm, 'mm')

%% start camera controller
if 0
    wc=CameraViewerStd('WinVideo.Controller','ImageViewerStd',figure,'Webcam Viewer');
    set(wc.processor.flatten_colour,'Value',1);
else
    wc = CameraViewerStd('GENTL.Controller','ImageViewerStd',figure,'GENTL (AVT) Viewer');
    
    %% set binning
    wc.processor.binning.binx.Value = 4;
    wc.processor.binning.biny.Value = 4;
    set(wc.processor.binning.do,'Value',1)
end

%% take image for testing
if 0
    %%
    wc.camera.take_snapshot;
    im=wc.processor.image;
    x=wc.processor.x;
    y=wc.processor.y;
    figureNF('image');clf
    imagesc(x,y,im)
end

%% define settings, parameters and values

% general settings
sett.pic_size   = size(wc.camera.take_snapshot);
sett.processed  = size(wc.processor.image);
sett.N_pic      = 3;                                   % number of pictures
sett.x          = wc.processor.x;
sett.y          = wc.processor.y;
sett.binx       = wc.processor.binning.binx.Value;
sett.biny       = wc.processor.binning.biny.Value;

% actuator parameters
att.center      = 14.2;                                   % mm
att.step_min    = 0.047625/1000;                        % um/1000 = mm
att.step        = att.step_min;                         % mm
att.N           = pow2(8); % step number as power of 2: 8 --> 256; 9 --> 512
att.min         = att.center -  att.N   *att.step/2;    % mm
att.max         = att.center + (att.N-1)*att.step/2;    % mm
att.vect        = att.min:att.step:att.max;             % mm
att.vect_read   = [];

% arm parameters
arm.center      = 0;                                    % mm
arm.step_min    = 2*att.step_min;                       % mm
arm.step        = 2*att.step;                           % mm
arm.N           = att.N;    % step number
arm.min         = arm.center -  arm.N   *arm.step/2;    % mm from the center
arm.max         = arm.center + (arm.N-1)*arm.step/2;    % mm from the center
arm.vect        = arm.min:arm.step:arm.max;             % mm
arm.vect_read   = [];

% prepare variables for processed images (grayscale)
im_store        = zeros(sett.processed(1), sett.processed(2), sett.N_pic);
im_all          = zeros(sett.processed(1), sett.processed(2), att.N);

%% start acquisition of data

% move attuator before the start (solves the problem of inverting the direction)
z.move_absolute(2, att.vect(1)-0.2, 'mm');
pause(0.5);
z.move_absolute(2, att.vect(1)-0.1, 'mm');
pause(0.5);

% move attuator to the start and read position
z.move_absolute(2, att.vect(1), 'mm');
pause(0.5);
att.vect_read(1) = z.get_position(2,'mm');
arm.vect_read(1) = 0;

% take sett.N_pic photos to average
for j=1:sett.N_pic
    wc.camera.take_snapshot;
    im_store(:,:,j) = wc.processor.image;
end
    
% get average of sett.N_pic photos
im_all(:,:,1) = mean(im_store,3);

for n=2:att.N
    % move attuator and read position
    z.move_relative(2, att.step, 'mm');
    att.vect_read(n) = z.get_position(2,'mm');
    arm.vect_read(n) = 2*(att.vect_read(n) - att.vect_read(n-1)) + arm.vect_read(n-1);

    % take sett.N_pic photos to average
    for j=1:sett.N_pic
        wc.camera.take_snapshot;
        im_store(:,:,j) = wc.processor.image;
    end
    
    % get average of sett.N_pic photos
    im_all(:,:,n) = mean(im_store,3);
    
end
clear im_store n j ans

% shift arm.vect such that the n/2+1 position in equal to 0
arm.vect_0 = arm.vect_read - arm.vect_read(att.N/2+1);