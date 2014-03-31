function gui
    % GUI GUI for controlling KITT
    % Add paths
    addpath(genpath('callbacks'));
    addpath(genpath('kitt'));
    addpath(genpath('ui'));
    addpath(genpath('defs'));
    
    display '[SYSTEM] Building interface';
    global connected;
    global controlling; controlling = 0;
    global tracking; tracking = 0;
    global running; running = 1;
    global sensor_mode; sensor_mode = SensorMode.LEFT;
    global use_lpfilter; use_lpfilter = 0;
    global use_pfilter; use_pfilter = 0;
    global want_to_disconnect; want_to_disconnect = 0;
    global snaps;
    
    if (exist('snaps.mat','file'))
        display '[SNAPSHOT] Loading snapshots';
        load('snaps.mat');
    else
        snaps = {};
    end
    
    width = 1200;
    height = 800;
    screenSize = get(0,'ScreenSize');
    
    global fig;
	fig = figure(...
       'Units', 'pixels',...
       'NumberTitle','off',...
       'Menubar','none',...
       'Visible', 'off',...
       'Position', [...
           (screenSize(3)-width)/2 ...
           (screenSize(4)-height)/2 ...
           width...
           height],...
        'Name', 'KITT CONTROL',...
        'Resize', 'Off',...
        'WindowKeyPressFcn', {@key_press},...
        'CloseRequestFcn', @close_window...
        );
    
    %% BUTTONS
    % Connect button
	global butConnect;
    global butConnectBusy;
    butConnect = uicontrol(...
        'Style', 'pushbutton',...
        'String', 'CONNECT <K>',...
        'Position', [20 (height-110) 180 30],...
        'Callback', {@butConnect_callback},...
        'FontSize', 14 ...
        );
    
    % Connect button
    global butTrack;
    butTrack = uicontrol(...
        'Style', 'pushbutton',...
        'String', 'TRACK <T>',...
        'Position', [20 (height-150) 180 30],...
        'Callback', {@butTrack_callback},...
        'FontSize', 14 ...
        );
    
    % Control button
    global butControl;
    butControl = uicontrol(...
        'Style', 'pushbutton',...
        'String', 'CONTROL <C>',...
        'Position', [20 (height-190) 180 30],...
        'Callback', {@butControl_callback},...
        'FontSize', 14 ...
        );
    
    % Sensor button
    global butSensor;
    butSensor = uicontrol(...
        'Style', 'pushbutton',...
        'String', 'LEFT SENSOR <S>',...
        'Position', [220 (height-110) 180 30],...
        'Callback', {@butSensor_callback},...
        'FontSize', 14 ...
        );
    
    % Low-pass filter button
    global butLPFilter;
    butLPFilter = uicontrol(...
        'Style', 'pushbutton',...
        'String', 'LP FILTER OFF <L>',...
        'Position', [220 (height-150) 180 30],...
        'Callback', {@butLPFilter_callback},...
        'FontSize', 14 ...
        );
    
    % Prediction filter
    global butPFilter;
    butPFilter = uicontrol(...
        'Style', 'pushbutton',...
        'String', 'PRED FILTER OFF <P>',...
        'Position', [220 (height-190) 180 30],...
        'Callback', {@butPFilter_callback},...
        'FontSize', 14 ...
        );
    
    % Snap
    global butSnap;
    butSnap = uicontrol(...
        'Style', 'pushbutton',...
        'String', 'SNAPSHOT',...
        'Position', [220 (height-351) 180 30],...
        'Callback', {@butSnap_callback},...
        'FontSize', 14 ...
        );
    
    % Load
    global butLoad;
    butLoad = uicontrol(...
        'Style', 'pushbutton',...
        'String', 'LOAD BEST',...
        'Position', [220 (height-391) 180 30],...
        'Callback', {@butLoad_callback},...
        'FontSize', 14 ...
        );
    
    %% LABELS
    % Status label
    global labStatus;
    labStatus = create_fancy_label(...
        20,... x
        height-50,... y
        380,... width
        30,... height
        5 ... padding
        );
    set(labStatus.text,...
        'String', 'Unconnected',...
        'FontSize', 16 ...
        );
    
    % Battery voltage label
    global labBat;
    labBat = create_fancy_label(...
        20,... x
        height-350,... y
        180,... width
        30,... height
        5 ... padding
        );
    set(labBat.text,...
        'String', 'Battery voltage: n.a.',...
        'FontSize', 14,...
        'HorizontalAlignment', 'Left'...
        );
    
    % Time label
    global labTime;
    labTime = create_fancy_label(...
        20,... x
        height-390,... y
        180,... width
        30,... height
        5 ... padding
        );
    set(labTime.text,...
        'String', 'Time: n.a.',...
        'FontSize', 14,...
        'HorizontalAlignment', 'Left'...
        );
    
    % Time label
    global labSampleTime;
    labSampleTime = create_fancy_label(...
        20,... x
        height-430,... y
        180,... width
        30,... height
        5 ... padding
        );
    set(labSampleTime.text,...
        'String', 'Sample time: n.a.',...
        'FontSize', 14,...
        'HorizontalAlignment', 'Left'...
        );
    
    % Processing time label
    global labProcTime;
    labProcTime = create_fancy_label(...
        220,... x
        height-430,... y
        180,... width
        30,... height
        5 ... padding
        );
    set(labProcTime.text,...
        'String', 'Processing time: n.a.',...
        'FontSize', 14,...
        'HorizontalAlignment', 'Left'...
        );
    
    % Reference label
    global labRef;
    labRef = create_fancy_label(...
        20,... x
        height-490,... y
        180,... width
        30,... height
        5 ... padding
        );
    set(labRef.text,...
        'String', 'Reference: 0.5m',...
        'FontSize', 14,...
        'HorizontalAlignment', 'Left'...
        );
    
    % Mapping f.o.c. label
    global labFOC;
    labFOC = create_fancy_label(...
        20,... x
        height-575,... y
        180,... width
        30,... height
        5 ... padding
        );
    set(labFOC.text,...
        'String', 'Mapping f.o.c.: 2',...
        'FontSize', 14,...
        'HorizontalAlignment', 'Left'...
        );
    
    % Mapping t.o.c. label
    global labTOC;
    labTOC = create_fancy_label(...
        20,... x
        height-640,... y
        180,... width
        30,... height
        5 ... padding
        );
    set(labTOC.text,...
        'String', 'Mapping t.o.c.: -0.025',...
        'FontSize', 14,...
        'HorizontalAlignment', 'Left'...
        );
    
    % Mapping bound label
    global labBound;
    labBound = create_fancy_label(...
        20,... x
        height-705,... y
        180,... width
        30,... height
        5 ... padding
        );
    set(labBound.text,...
        'String', 'Mapping bound: 0.04',...
        'FontSize', 14,...
        'HorizontalAlignment', 'Left'...
        );
    
    % Weight label
    global labWeight;
    labWeight = create_fancy_label(...
        220,... x
        height-575,... y
        180,... width
        30,... height
        5 ... padding
        );
    set(labWeight.text,...
        'String', 'Weight: 0.4kg',...
        'FontSize', 14,...
        'HorizontalAlignment', 'Left'...
        );
    
    % Resistance label
    global labRes;
    labRes = create_fancy_label(...
        220,... x
        height-640,... y
        180,... width
        30,... height
        5 ... padding
        );
    set(labRes.text,...
        'String', 'Resistance: 0.020',...
        'FontSize', 14,...
        'HorizontalAlignment', 'Left'...
        );
    
    % Compensator label
    global labPoles;
    labPoles = create_fancy_label(...
        220,... x
        height-705,... y
        180,... width
        30,... height
        5 ... padding
        );
    set(labPoles.text,...
        'String', 'Poles: -1.50',...
        'FontSize', 14,...
        'HorizontalAlignment', 'Left'...
        );
    
    %% AXES
    % Distance plot
    global aDist;
    aDist = axes(...
    	'Parent', fig,...
        'Units', 'Pixels',...
        'Position', [width-700-20 height-330-20 700 330],...
        'FontSize', 14,...
        'XGrid', 'on',...
        'YGrid', 'on',...
        'XTick', 0:1:Cfg.PlotTimeFrame,...
        'YTick', 0:0.5:4 ...
        );
    xlabel(aDist, 'Time (s)');
    ylabel(aDist, 'Distance (m)');
    xlim(aDist, [0 Cfg.PlotTimeFrame]);
    ylim(aDist, [0 3.1]);
    global lDistLeft;
    lDistLeft = line(0,0,'Color',[0 0 1]);
    global lDistRight;
    lDistRight = line(0,0,'Color',[1 0 0]);
    global lDistFilt;
    lDistFilt = line(0,0,'Color',[1 0 1]);
    global lDistRef;
    lDistRef = line(0,0,'Color',[0 0 0]);
    global lDistInt;
    lDistInt = line(0,0,'Color',[0.5 0 0.5]);
    set(aDist,'Children',[lDistLeft lDistRight lDistFilt lDistRef lDistInt]);
    legend(...
        [lDistLeft lDistRight lDistFilt lDistRef lDistInt],...
        {'Left sensor','Right sensor','Filtered','Reference','Internal'}...
        );
    
    % Excitation plot
    global aExPWM;
    aExPWM = axes(...
    	'Parent', fig,...
        'Units', 'Pixels',...
        'Position', [width-700-20 height-330-20-400 660 330],...
        'FontSize', 14,...
        'XGrid', 'on',...
        'YGrid', 'on',...
        'XTick', 0:1:Cfg.PlotTimeFrame,...
        'YTick', 135:5:165,...
        'YColor', 'b',...
        'YAxisLocation','left'...
        );
    ylabel(aExPWM, 'PWM');
    xlim(aExPWM, [0 Cfg.PlotTimeFrame]);
    ylim(aExPWM, [135 165]);
    global lExPWM;
    lExPWM = line(0,0,'Color',[0 0 1]);
    set(aExPWM,'Children',lExPWM);
    global aExForce;
    aExForce = axes(...
    	'Parent', fig,...
        'Units', 'Pixels',...
        'Position', [width-700-20 height-330-20-400 660 330],...
        'FontSize', 14,...
        'XGrid', 'on',...
        'YGrid', 'on',...
        'XTick', 0:1:Cfg.PlotTimeFrame,...
        'YTick', -4:2:4,...
        'Color','none',...
        'YColor','r',...
        'YAxisLocation','right'...
        );
    xlabel(aExForce, 'Time (s)');
    ylabel(aExForce, 'Force (N)');
    xlim(aExForce, [0 Cfg.PlotTimeFrame]);
    ylim(aExForce, [-2 2]);
    global lExForce;
    lExForce = line(0,0,'Color',[1 0 0]);
    set(aExForce,'Children',lExForce);
    
    %% SLIDERS
    % Reference
    global sRef;
    sRef = uicontrol(...
        'Style', 'Slider',...
    	'Max', 3,...
        'Min', .2,...
        'Value', .5,...
    	'SliderStep', [.1/2.8 .1/2.8],...
    	'Position', [20 height-520 180 20]);
    addlistener(...
        sRef, 'Value',...
        'PostSet', @sRef_value_callback...
        );
    
    % Mapping f.o.c.
    global sFOC;
    sFOC = uicontrol(...
        'Style', 'Slider',...
    	'Max', 4,...
        'Min', 0,...
        'Value', 2,...
    	'SliderStep', [.025 .025],...
    	'Position', [20 height-605 180 20]);
    addlistener(...
        sFOC, 'Value',...
        'PostSet', @sFOC_value_callback...
        );
    
    % Mapping t.o.c.
    global sTOC;
    sTOC = uicontrol(...
        'Style', 'Slider',...
    	'Max', 0.05,...
        'Min', -0.05,...
        'Value', -0.025,...
    	'SliderStep', [.01 .01],...
    	'Position', [20 height-670 180 20]);
    addlistener(...
        sTOC, 'Value',...
        'PostSet', @sTOC_value_callback...
        );
    
    % Mapping bound
    global sBound;
    sBound = uicontrol(...
        'Style', 'Slider',...
    	'Max', 0.2,...
        'Min', 0,...
        'Value', 0.04,...
    	'SliderStep', [0.01/2*5 .01/2*5],...
    	'Position', [20 height-735 180 20]);
    addlistener(...
        sBound, 'Value',...
        'PostSet', @sBound_value_callback...
        );
    
    % Weight
    global sWeight;
    sWeight = uicontrol(...
        'Style', 'Slider',...
    	'Max', 1,...
        'Min', 0,...
        'Value', 0.4,...
    	'SliderStep', [0.05 .05],...
    	'Position', [220 height-605 180 20]);
    addlistener(...
        sWeight, 'Value',...
        'PostSet', @sWeight_value_callback...
        );
    
    % Resistance
    global sRes;
    sRes = uicontrol(...
        'Style', 'Slider',...
    	'Max', 0.15,...
        'Min', 0,...
        'Value', 0.02,...
    	'SliderStep', [0.0125/2 .0125/2],...
    	'Position', [220 height-670 180 20]);
    addlistener(...
        sRes, 'Value',...
        'PostSet', @sRes_value_callback...
        );
    
    % Poles
    global sPoles;
    sPoles = uicontrol(...
        'Style', 'Slider',...
    	'Max', 0,...
        'Min', -4,...
        'Value', -1.5,...
    	'SliderStep', [0.025/2 0.025/2],...
    	'Position', [220 height-735 180 20]);
    addlistener(...
        sPoles, 'Value',...
        'PostSet', @sPoles_value_callback...
        );


    %% FINISH
    % Finish gui
    set(fig, 'Visible', 'on');
    
    connected = 0;
    butConnectBusy = 0;
    
    display '[SYSTEM] Starting loop'
    loop();     
    display '[SYSTEM] Done';
end