function temporaryDlg(mssg,pauseval)
%TEMPORARYDLG Populate a temporary informational dialog box that
%   automatically closes after PAUSEVAL seconds.
%   
% Brett Shoelson, PhD
% brett.shoelson@mathworks.com
% 02/14/2018

if nargin < 2
    pauseval = 3;
end
ss = get(0,'screensize');
width = 400;
pos = [ss(3)/2-width/2 400 width 200];

tmpBox = dialog('Position',pos,...
    'Name','Auto-closing dialog',...
    'WindowStyle','normal');
uicontrol('Parent',tmpBox,...
    'Style','text',...
    'Units','normalized',...
    'fontsize',14,...
    'Position',[0.05 0.2 0.9 0.6],...
    'String',mssg);
pause(pauseval)
delete(tmpBox)
end

