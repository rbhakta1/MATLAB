function [SE,strelVal,parentHndl,radioButtons,sliderHandles,strelShapeButtonGroup,diskPopup] = ...
	StrelTool(parentHndl,varName,triggerUpdate)
% Interactive GUI for defining structuring elements (STRELs)
%
% Assigns the current STREL to the base workspace with name defined by
% editable "Variable Name" (default is "SE"). Also stores the same STREL in
% the appdata container of the parent of the STRELTOOL instance.
%
% This tool can be used as a standalone STREL-defining GUI, or as a child
% of a larger tool (like MorphTool).
%
% See also: strel, MorphTool, SegmentTool

% Written by Brett Shoelson, Ph.D.
% brett.shoelson@mathworks.com
% Copyright The MathWorks, 2010.

% IF TRIGGERUPDATE: update, do not create
if nargin < 3
	triggerUpdate = false;
end
if triggerUpdate
	[SE,strelVal] = updateSE(parentHndl);
	%strelVal
	return
end

colors = bone(20);
colors = colors(10:end,:);
bgc = colors(4,:);
highlightColor = colors(9,:);

if nargin == 0 || ~ishandle(parentHndl)
	parentHndl = figure('menubar','none',...
		'numbertitle','off',...
		'name','StrelTool',...
		'units','normalized',...
		'windowstyle','normal',...
		'color',bgc,...
		'pos',[0.4 0.3 0.45 0.5],...
		'tag','StrelTool');
end

if nargin < 2
	varName = 'SE';
end

try
	bgc = get(parentHndl,'color');
catch
	try
		bgc = get(parentHndl,'backgroundcolor');
	catch
		bgc = colors(4,:);
	end
end

figParent = ancestor(parentHndl,'figure');

strelShapeButtonGroup = uibuttongroup('Parent', parentHndl,...
	'BorderType', 'etchedin',...
	'FontSize',8,...
	'ForegroundColor',[0 0 0],...
	'Title','Shape',...
	'TitlePosition','lefttop',...
	'backgroundColor',bgc,...
	'Units','normalized',...
	'Position',[0.02 0.34-0.05 0.35 0.64+0.05]);

strelShapes = {'Arbitrary','Ball','Diamond','Disk',...
	'Line','Octagon','Pair','Periodicline',...
	'Rectangle','Square'};
[objpos, objdim] = distributeObjects(numel(strelShapes),0.95,0.05,0.025);
panelOpts.Parent = parentHndl;
panelOpts.Units = 'normalized';
panelOpts.Position = [0.39 0.34-0.05 0.59 0.64+0.05];
panelOpts.BorderType = 'etchedin';
panelOpts.FontSize = 8;
panelOpts.FontUnits = 'points';
panelOpts.ForegroundColor = [0 0 0];
panelOpts.HighlightColor = highlightColor;
panelOpts.TitlePosition = 'lefttop';
panelOpts.backgroundColor = bgc;
panelOpts.Tag = 'strelparameters';
panelOpts.Visible = 'off';

shapePanel = gobjects(numel(strelShapes,1));
radioButtons = gobjects(numel(strelShapes,1));
for ii = 1:numel(strelShapes)
	shapePanel(ii) = uipanel(panelOpts,'title',strelShapes{ii});
	radioButtons(ii) = uicontrol('parent',strelShapeButtonGroup,...
		'style','radio',...
		'units','normalized',...
		'pos',[0.05 objpos(ii) 0.9 objdim],...
		'tag','StrelToolRadioButtons',...
		'backgroundcolor',bgc,...
		'string',strelShapes{ii},...
		'value',0); %#ok<AGROW>
end
set(strelShapeButtonGroup,'selectionChangeFcn',@radioCB);

commentPnl = uipanel(panelOpts,'Title','',...
	'Position',	[0.02 0.07-0.05 0.96 0.25],...
	'tag','CommentPnl');

msgstr = {[varName ' = strel(''disk'', R, N) creates a flat, disk-shaped structuring element',...
	'',...
	'RADIUS must be a nonnegative integer. N must be 0, 4 (DEFAULT), 6, or 8. When N is greater than 0, the disk-shaped structuring element is approximated by a sequence of N periodic-line structuring elements. When N equals 0, no approximation is used, and the structuring element members consist of all pixels whose centers are no greater than R away from the origin.']};
commentBox = uicontrol('parent',commentPnl,...
	'style','edit',...
	'units','normalized',...
	'pos',[0.02 0.05 0.96 0.9],...
	'backgroundcolor',highlightColor,...
	'min',1,'max',3,...
	'string',msgstr,...
	'fontsize',8,...
	'HorizontalAlignment','left');

set([shapePanel(4),commentPnl],'visible','on');
set(strelShapeButtonGroup,'SelectedObject',radioButtons(4))

% uicontrol('parent',parentHndl,...
% 	'style','text','units','normalized',...
% 	'Position',[0.02 0.016 0.4 0.045],...
% 	'string',...
% 	'Variable Name:',...
% 	'backgroundColor',bgc,...
% 	'FontSize',7,...
% 	'ForegroundColor',[0 0 0],...
% 	'HorizontalAlignment','left');
% varNameBox = uicontrol('parent',parentHndl,...
% 	'style','edit',...
% 	'units','normalized',...
% 	'Position',[0.45 0.016 0.16 0.042],...
% 	'string',varName,...
% 	'backgroundColor',highlightColor,...
% 	'FontSize',7,...
% 	'ForegroundColor',[0 0 0],...
% 	'Tag','VarNameBox',...
% 	'HorizontalAlignment','center',...
% 	'callback',{@changeVarName,parentHndl});
%setappdata(varNameBox,'varName',varName);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Shape-specific parameters

% [sliderHandle,panelHandle,editHandle] = sliderPanel(parent,PanelPVs,SliderPVs,EditPVs,LabelPVs,numFormat)

% Provide for 3 sub-panels per panel
[objpos, objdim] = distributeObjects(3,0.025,0.975,0.015);

%%%%%%%%%%%%%%%%%
% BALL
parent = findobj(parentHndl,'type','uipanel','title','Ball');
sliderHandles(1) = sliderPanel(parent, ...
	{'title','Radius',...
	'pos',[0.05 objpos(3) 0.9 objdim],...
	'backgroundcolor', bgc,...
	'fontsize',7},...
	{'backgroundcolor', highlightColor,...
	'min',0,'max',100,...
	'value',0,...
	'tag','ballrad',...
	'callback',{@updateSE,parentHndl}},...
	{'backgroundcolor',highlightColor,...
	'fontsize',7},...
	{'backgroundcolor', bgc,...
	'fontsize',7},...
	'%0.0f');
sliderHandles(2) = sliderPanel(parent, ...
	{'title','Height',...
	'pos',[0.05 objpos(2) 0.9 objdim],...
	'backgroundcolor', bgc,...
	'fontsize',7},...
	{'backgroundcolor', highlightColor,...
	'min',-15,'max',50,...
	'value',0,...
	'tag','ballheight',...
	'callback',{@updateSE,parentHndl}},...
	{'backgroundcolor',highlightColor,...
	'fontsize',7},...
	{'backgroundcolor', bgc,...
	'fontsize',7},...
	'%0.2f');
[sliderHandles(3),tmp,ballNText] = sliderPanel(parent, ...
	{'title','N',...
	'pos',[0.05 objpos(1) 0.9 objdim],...
	'backgroundcolor', bgc,...
	'fontsize',7},...
	{'backgroundcolor', highlightColor,...
	'min',0,'max',50,...
	'value',0,...
	'tag','ballN',...
	'callback',{@updateSE,parentHndl},...
	'sliderstep',[2 12]/50},...
	{'backgroundcolor',highlightColor,...
	'fontsize',7},...
	{'backgroundcolor', bgc,...
	'fontsize',7},...
	'%0.0f');
%%%%%%%%%%%%%%%%%

%%%%%%%%%%%%%%%%%
% DIAMOND
parent = findobj(parentHndl,'type','uipanel','title','Diamond');
sliderHandles(4) = sliderPanel(parent, ...
	{'title','Distance to Origin',...
	'pos',[0.05 objpos(3) 0.9 objdim],...
	'backgroundcolor', bgc,...
	'fontsize',7},...
	{'backgroundcolor', highlightColor,...
	'min',0,'max',100,...
	'value',3,...
	'tag','diamondrad',...
	'callback',{@updateSE,parentHndl}},...
	{'backgroundcolor',highlightColor,...
	'fontsize',7},...
	{'backgroundcolor', bgc,...
	'fontsize',7},...
	'%0.0f');
%%%%%%%%%%%%%%%%%

%%%%%%%%%%%%%%%%%
% DISK
parent = findobj(parentHndl,...
	'type','uipanel',...
	'title','Disk');
sliderHandles(5) = sliderPanel(parent, ...
	{'title','Radius',...
	'pos',[0.05 objpos(3) 0.9 objdim],...
	'backgroundcolor', bgc,...
	'fontsize',7},...
	{'backgroundcolor', highlightColor,...
	'min',0,'max',100,...
	'value',0,...
	'tag','diskrad',...
	'callback',{@updateSE,parentHndl}},...
	{'backgroundcolor',highlightColor,...
	'fontsize',7},...
	{'backgroundcolor', bgc,...
	'fontsize',7},...
	'%0.0f');

uicontrol('parent',parent,...
	'style','text',...
	'fontsize',7,...
	'string','N =',...
	'units','normalized',...
	'pos',[0.05 objpos(2) 0.1 0.2],...
	'backgroundcolor',bgc)
diskPopup = uicontrol('parent',parent,...
	'style','popupmenu',...
	'string',[0 4 6 8],...
	'units','normalized',...
	'pos',[0.175 objpos(2)+0.075 0.2 0.15],...
	'value',2,...
	'callback',{@updateSE,parentHndl},...
	'tag','diskN',...
	'backgroundcolor',highlightColor);

% Initial:
SE = strel('disk',0);
strelVal.type = 'Disk';
strelVal.opt1 = 0;
%%%%%%%%%%%%%%%%%

%%%%%%%%%%%%%%%%%
% LINE
parent = findobj(parentHndl,...
	'type','uipanel',...
	'title','Line');
sliderHandles(6) = sliderPanel(parent, ...
	{'title','Length',...
	'pos',[0.05 objpos(3) 0.9 objdim],...
	'backgroundcolor', bgc,...
	'fontsize',7},...
	{'backgroundcolor', highlightColor,...
	'min',0,'max',200,...
	'value',10,...
	'tag','linelength',...
	'callback',{@updateSE,parentHndl},...
	'sliderstep',[1 10]/200},...
	{'backgroundcolor',highlightColor,...
	'fontsize',7},...
	{'backgroundcolor', bgc,...
	'fontsize',7},...
	'%0.1f');
sliderHandles(7) = sliderPanel(parent, ...
	{'title','Angle','pos',[0.05 objpos(2) 0.9 objdim],...
	'backgroundcolor', bgc,'fontsize',7},...
	{'backgroundcolor', highlightColor,...
	'min',-180,'max',180,...
	'value',0,...
	'tag','lineangle',...
	'callback',{@updateSE,parentHndl},...
	'sliderstep',[5 15]/360},...
	{'backgroundcolor',highlightColor,...
	'fontsize',7},...
	{'backgroundcolor', bgc,...
	'fontsize',7},...
	'%0.1f');
%%%%%%%%%%%%%%%%%

%%%%%%%%%%%%%%%%%
% OCTAGON
parent = findobj(parentHndl,...
	'type','uipanel',...
	'title','Octagon');
[sliderHandles(8),tmp,octagonText] = sliderPanel(parent, ...
	{'title','Distance to Origin',...
	'pos',[0.05 objpos(3) 0.9 objdim],...
	'backgroundcolor', bgc,...
	'fontsize',7},...
	{'backgroundcolor', highlightColor,...
	'min',0,'max',100,...
	'value',3,...
	'tag','octagonrad',...
	'callback',{@updateSE,parentHndl},...
	'sliderstep',[3 12]/100},...
	{'backgroundcolor',highlightColor,...
	'fontsize',7},...
	{'backgroundcolor', bgc,...
	'fontsize',7},...
	'%0.0f');
%%%%%%%%%%%%%%%%%

%%%%%%%%%%%%%%%%%
% PAIR
parent = findobj(parentHndl,...
	'type','uipanel',...
	'title','Pair');
sliderHandles(9) = sliderPanel(parent, ...
	{'title','Horizontal Offset',...
	'pos',[0.05 objpos(3) 0.9 objdim],...
	'backgroundcolor', bgc,...
	'fontsize',7},...
	{'backgroundcolor', highlightColor,...
	'min',0,'max',40,...
	'value',2,...
	'tag','pairhoffset',...
	'callback',{@updateSE,parentHndl},...
	'sliderstep',[1 5]/40},...
	{'backgroundcolor',highlightColor,...
	'fontsize',7},...
	{'backgroundcolor', bgc,...
	'fontsize',7},...
	'%0.0f');
sliderHandles(10) = sliderPanel(parent, ...
	{'title','Vertical',...
	'pos',[0.05 objpos(2) 0.9 objdim],...
	'backgroundcolor', bgc,...
	'fontsize',7},...
	{'backgroundcolor', highlightColor,...
	'min',0,'max',40,...
	'value',2,...
	'tag','pairvoffset',...
	'callback',{@updateSE,parentHndl},...
	'sliderstep',[1 5]/40},...
	{'backgroundcolor',highlightColor,...
	'fontsize',7},...
	{'backgroundcolor', bgc,...
	'fontsize',7},...
	'%0.0f');
%%%%%%%%%%%%%%%%%

%%%%%%%%%%%%%%%%%
% PERIODICLINE
parent = findobj(parentHndl,...
	'type','uipanel',...
	'title','Periodicline');
[sliderHandles(11),tmp,periodiclinePText] = sliderPanel(parent, ...
	{'title','Members',...
	'pos',[0.05 objpos(3) 0.9 objdim],...
	'backgroundcolor', bgc,...
	'fontsize',7},...
	{'backgroundcolor', highlightColor,...
	'min',1,'max',45,...
	'value',1,...
	'tag','periodiclineP',...
	'callback',{@updateSE,parentHndl},...
	'sliderstep',[2 10]/44},...
	{'backgroundcolor',highlightColor,...
	'fontsize',7},...
	{'backgroundcolor',...
	bgc,'fontsize',7},...
	'%0.0f');
sliderHandles(12) = sliderPanel(parent, ...
	{'title','Horizontal Offset',...
	'pos',[0.05 objpos(2) 0.9 objdim],...
	'backgroundcolor', bgc,...
	'fontsize',7},...
	{'backgroundcolor', highlightColor,...
	'min',0,'max',500,...
	'value',2,...
	'tag','periodiclineH',...
	'callback',{@updateSE,parentHndl},...
	'sliderstep',[1 20]/500},...
	{'backgroundcolor',highlightColor,...
	'fontsize',7},...
	{'backgroundcolor', bgc,...
	'fontsize',7},...
	'%0.0f');
sliderHandles(13) = sliderPanel(parent, ...
	{'title','Vertical',...
	'pos',[0.05 objpos(1) 0.9 objdim],...
	'backgroundcolor', bgc,...
	'fontsize',7},...
	{'backgroundcolor', highlightColor,...
	'min',0,'max',500,...
	'value',2,...
	'tag','periodiclineV',...
	'callback',{@updateSE,parentHndl},...
	'sliderstep',[1 20]/500},...
	{'backgroundcolor',highlightColor,...
	'fontsize',7},...
	{'backgroundcolor', bgc,...
	'fontsize',7},...
	'%0.0f');
%%%%%%%%%%%%%%%%%

%%%%%%%%%%%%%%%%%
% RECTANGLE
parent = findobj(parentHndl,...
	'type','uipanel',...
	'title','Rectangle');
sliderHandles(14) = sliderPanel(parent, ...
	{'title','Rows',...
	'pos',[0.05 objpos(3) 0.9 objdim],...
	'backgroundcolor', bgc,...
	'fontsize',7},...
	{'backgroundcolor', highlightColor,...
	'min',0,'max',100,...
	'value',2,...
	'tag','rectangleR',...
	'callback',{@updateSE,parentHndl}},...
	{'backgroundcolor',highlightColor,...
	'fontsize',7},...
	{'backgroundcolor', bgc,...
	'fontsize',7},...
	'%0.0f');
sliderHandles(15) = sliderPanel(parent, ...
	{'title','Cols',...
	'pos',[0.05 objpos(2) 0.9 objdim],...
	'backgroundcolor', bgc,...
	'fontsize',7},...
	{'backgroundcolor', highlightColor,...
	'min',0,'max',100,...
	'value',2,...
	'tag','rectangleC',...
	'callback',{@updateSE,parentHndl}},...
	{'backgroundcolor',highlightColor,...
	'fontsize',7},...
	{'backgroundcolor', bgc,...
	'fontsize',7},...
	'%0.0f');
%%%%%%%%%%%%%%%%%

%%%%%%%%%%%%%%%%%
% SQUARE
parent = findobj(parentHndl,...
	'type','uipanel',...
	'title','Square');
sliderHandles(16) = sliderPanel(parent, ...
	{'title','Width',...
	'pos',[0.05 objpos(3) 0.9 objdim],...
	'backgroundcolor', bgc,...
	'fontsize',7},...
	{'backgroundcolor', highlightColor,...
	'min',0,'max',100,...
	'value',2,...
	'tag','squareW',...
	'callback',{@updateSE,parentHndl}},...
	{'backgroundcolor',highlightColor,...
	'fontsize',7},...
	{'backgroundcolor', bgc,...
	'fontsize',7},...
	'%0.0f');
%%%%%%%%%%%%%%%%%
set(sliderHandles,...
	'Interruptible','on',...
	'busyaction','cancel')
if nargout == 0
	clear SE
end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% --- Executes on button press in strelshape.
	function changeVarName(varargin)
		parentHndl = varargin{3};
		%oldName = getappdata(varargin{1},'varName');
		varName = get(varargin{1},'string');
	end

	function radioCB(hObject,currentButtons,varargin)
		try
			strelType = get(get(strelShapeButtonGroup,'SelectedObject'),'String');
		catch
			strelType = get(currentButtons.NewValue,'string');
		end
		if ~exist('parentHndl','var')
			parentHndl = ancestor(hObject,...
				'figure','toplevel');
		end
		set(findobj(parentHndl,...
			'type','uipanel',...
			'tag','strelparameters'),...
			'visible','off');
		set(findobj(parentHndl,...
			'type','uipanel',...
			'title',strelType),...
			'visible','on');
		msgstr = '';
		switch strelType
			case 'Arbitrary'
				msgstr = sprintf('\nPlease create an ARBITRARY structuring element, named "ArbStrel", manually IN THE BASE WORKSPACE.\n(See STREL DOCUMENTATION for assistance.)\n\n');
			case 'Ball'
				msgstr = {'SE = strel(''ball'', R, H, N) creates a nonflat, ball-shaped structuring element (actually an ellipsoid) whose radius in the X-Y plane is R and whose height is H.',...
					' ',...
					'Note that R must be a nonnegative integer, H must be a real scalar, and N must be an even nonnegative integer. When N is greater than 0, the ball-shaped structuring element is approximated by a sequence of N nonflat, line-shaped structuring elements. When N equals 0, no approximation is used, and the structuring element members consist of all pixels whose centers are no greater than R away from the origin. The corresponding height values are determined from the formula of the ellipsoid specified by R and H. If N is not specified, the default value is 8.',...
					'',...
					'NOTE: Morphological operations run much faster when the structuring element uses approximations (N > 0) than when it does not (N = 0).'};
			case 'Diamond'
				msgstr = {'SE = strel(''diamond'', R) creates a flat, diamond-shaped structuring element.',...
					'',...
					'R specifies the distance from the structuring element origin to the points of the diamond. R must be a nonnegative integer scalar.'};
			case 'Disk'
				msgstr = {'SE = strel(''disk'', R, N) creates a flat, disk-shaped structuring element',...
					'',...
					'RADIUS must be a nonnegative integer. N must be 0, 4 (DEFAULT), 6, or 8. When N is greater than 0, the disk-shaped structuring element is approximated by a sequence of N periodic-line structuring elements. When N equals 0, no approximation is used, and the structuring element members consist of all pixels whose centers are no greater than R away from the origin.'};
			case 'Line'
				msgstr = {'SE = strel(''line'', LEN, DEG) creates a flat, linear structuring element.',...
					'',...
					'LEN specifies the length, and DEG specifies the angle (in degrees) of the line, as measured in a counterclockwise direction from the horizontal axis. LEN is approximately the distance between the centers of the structuring element members at opposite ends of the line.'};
			case 'Octagon'
				msgstr = {'SE = strel(''octagon'', R) creates a flat, octagonal structuring element.',...
					'',...
					'R specifies the distance from the structuring element origin to the sides of the octagon, as measured along the horizontal and vertical axes. R must be a nonnegative multiple of 3.'};
			case 'Pair'
				msgstr = {'SE = strel(''pair'', OFFSET) creates a flat structuring element containing two members.',...
					'',...
					'One member is located at the origin. The second member''s location is specified by the vector OFFSET. OFFSET must be a two-element vector of integers.'};
			case 'Periodicline'
				msgstr = {'SE = strel(''periodicline'', P, V) creates a flat structuring element containing 2*P+1 members.',...
					'',...
					'V is a two-element vector containing integer-valued row and column offsets. One structuring element member is located at the origin. The other members are located at 1*V, -1*V, 2*V, -2*V, ..., P*V, -P*V.'};
			case 'Rectangle'
				msgstr = {'SE = strel(''rectangle'', MN) creates a flat, rectangle-shaped structuring element',...
					'',...
					'MN specifies the size. MN must be a two-element vector of nonnegative integers. The first element of MN is the number of rows in the structuring element neighborhood; the second element is the number of columns.'};
			case 'Square'
				msgstr = {'SE = strel(''square'', W) creates a square structuring element.',...
					'',...
					'W is the width, in pixels. W must be a nonnegative integer scalar.'};
		end
		set(commentBox,'string',msgstr);
		[SE,strelVal] = updateSE(parentHndl);
	end

	function [SE,strelVal] = updateSE(varargin)
		%This allows right-click reset slider to default to work
		parentHndl = varargin{end};
		if verLessThan('matlab','8.4')
			shapePanel = findall(parentHndl,...
				'type','uipanel',...
				'title','Shape');
			strelType = get(get(shapePanel,'SelectedObject'),'string');
		else
			shapePanel = findobj(parentHndl,...
				'Type','UIButtonGroup');
			strelType = shapePanel.SelectedObject.String;
		end
		strelVal.type = strelType;
		parent = findobj(parentHndl,...
			'type','uipanel',...
			'title',strelType);
		switch strelType
			case 'Arbitrary'
				try
					SE = evalin('base','ArbStrel');
				catch
					beep;
					fprintf('\nPlease define your arbitrary STREL, named "ArbStrel", in the Base Workspace.\n');
					SE = [];strelVal = [];
					return
				end
			case 'Ball'
				R = round(get(findobj(parent,'tag','ballrad'),'Value'));
				H = get(findobj(parent,'tag','ballheight'),'Value');
				N = get(findobj(parent,'tag','ballN'),'Value');
				if ~(N/2==floor(N/2))
					fprintf('N must be an even, non-negative integer. Using %d instead.\n',N+2-rem(N,2));
					N = N + 2 - rem(N,2);
					set(findobj(parent,'tag','ballN'),'Value',N);
					set(ballNText,'string',num2str(N));
				end
				SE = strel('ball',R,H,N);
				strelVal.opt1 = R;
				strelVal.opt2 = H;
				strelVal.opt3 = N;
			case 'Diamond'
				R = round(get(findobj(parent,'tag','diamondrad'),'Value'));
				SE = strel('diamond',R);
				strelVal.opt1 = R;
			case 'Disk'
				R = round(get(findobj(parent,'tag','diskrad'),'Value'));
				tmp = get(findobj(parent,'tag','diskN'),'Value');
				N = [0 4 6 8];
				N = N(tmp);
				SE = strel('disk',R,N);
				strelVal.opt1 = R;
				strelVal.opt2 = N;
			case 'Line'
				len = get(findobj(parent,'tag','linelength'),'Value');
				angle = get(findobj(parent,'tag','lineangle'),'Value');
				SE = strel('line',len,angle);
				strelVal.opt1 = len;
				strelVal.opt2 = angle;
			case 'Octagon'
				R = get(findobj(parent,'tag','octagonrad'),'Value');
				if ~(R/3==floor(R/3))
					fprintf('R must be an non-negative multiple of 3. Using %d instead.\n',R+3-rem(R,3));
					R = R + 3 - rem(R,3);
					set(findobj(parent,'tag','octagonrad'),'Value',R);
					set(octagonText,'string',num2str(R));
				end
				SE = strel('octagon',R);
				strelVal.opt1 = R;
			case 'Pair'
				H = round(get(findobj(parent,'tag','pairhoffset'),'Value'));
				V = round(get(findobj(parent,'tag','pairvoffset'),'Value'));
				SE = strel('pair',[H,V]);
				strelVal.opt1 = [H,V];
			case 'Periodicline'
				members = round(get(findobj(parent,'tag','periodiclineP'),'Value'));
				if rem(members,2) ~= 1 %members must be an odd positive integer
					fprintf('members must be an odd, non-negative integer. Using %d instead.\n',members+1);
					members = members + 1;
					set(findobj(parent,'tag','periodiclineP'),'Value',members);
					set(periodiclinePText,'string',num2str(members));
				end
				P = (members - 1)/2;
				H = round(get(findobj(parent,'tag','periodiclineH'),'Value'));
				V = round(get(findobj(parent,'tag','periodiclineV'),'Value'));
				SE = strel('periodicline',P,[H,V]);
				strelVal.opt1 = P;
				strelVal.opt2 = [H,V];
			case 'Rectangle'
				R = round(get(findobj(parent,'tag','rectangleR'),'Value'));
				C = round(get(findobj(parent,'tag','rectangleC'),'Value'));
				SE = strel('rectangle',[R,C]);
				strelVal.opt1 = [R,C];
			case 'Square'
				W = round(get(findobj(parent,'tag','squareW'),'Value'));
				SE = strel('square',W);
				strelVal.opt1 = W;
		end
		%strelVal
	end

if nargout == 0
	clear parentHndl
end

end
