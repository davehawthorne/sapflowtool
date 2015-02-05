close all;
fig = figure();
af1 = axes('Parent', fig, 'Position', [0.1, 0.8, 0.8, 0.1]);
af2 = axes('Parent', fig, 'Position', [0.1, 0.7, 0.8, 0.1]);
az1 = axes('Parent', fig, 'Position', [0.1, 0.4, 0.6, 0.2]);
az2 = axes('Parent', fig, 'Position', [0.1, 0.1, 0.6, 0.2]);
af1.Units = 'Pixels';
af2.Units = 'Pixels';
az1.Units = 'Pixels';
az2.Units = 'Pixels';

s.figure = fig;
s.fullPlots = {af1, af2};
s.zoomPlots = {az1, az2};




t = (0:0.1:1000);
y = 1 + 0.5 * cos(t);
iii = y > 1.25 & rand(1,length(t)) > 0.8;
tx = t(iii);
x = y(iii);

axs = {af1, af2, az1, az2};
grn = {};
red = {};
for i = 1:4
    hold(axs{i}, 'on');
    grn{i} = plot(axs{i}, t, y, 'g.-');
    red{i} = plot(axs{i}, tx, x, 'ro-');
    hold(axs{i}, 'off');
end


mz = MontyZoomer(s);

restoreY = @(~,~)mz.restoreY();

uicontrol( ...
    'Parent', fig, ...
    'Style', 'pushbutton', 'String', '<',...
    'Units', 'normalized', ...
    'Position', [0.8, 0.1, 0.03, 0.075], ...
    'Callback', @(~,~)mz.pan(-0.8));
uicontrol( ...
    'Parent', fig, ...
    'Style', 'pushbutton', 'String', '>',...
    'Units', 'normalized', ...
    'Position', [0.87, 0.1, 0.03, 0.075], ...
    'Callback', @(~,~)mz.pan(+0.8));
uicontrol( ...
    'Parent', fig, ...
    'Style', 'pushbutton', 'String', 'restoreY',...
    'Units', 'normalized', ...
    'Position', [0.8, 0.2, 0.1, 0.075], ...
    'Callback', restoreY);

uicontrol( ...
    'Parent', fig, ...
    'Style', 'pushbutton', 'String', 'setlimits',...
    'Units', 'normalized', ...
    'Position', [0.8, 0.3, 0.1, 0.075], ...
    'Callback', @(~,~) mz.setLimits(s));

s = {};
s.yLimits = {[0, 2], [-2, 2]};
s.xLimit = [0, 1000];
s.xZoom = [100, 150];



%mz.setLimits(s);      
 
 
