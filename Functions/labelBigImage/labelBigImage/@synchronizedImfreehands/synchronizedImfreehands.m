classdef synchronizedImfreehands < synchronizedROI
	% Syntax:
	%           vObj = synchronizedImfreehands()
	%           vObj = synchronizedImfreehands('p1',v1,...)
	%
	% Inputs:
	%           Optional property-value pairs for default synchronizedROI
	%
	% Outputs:
	%           vObj - synchronizedImfreehands object
	%
	% % Example:
	%
	%           hAx(1) = subplot(1,2,1);
	%           hAx(2) = subplot(1,2,2);
	%           title('DRAW HERE!','parent',hAx(1));
	%           baseROI = imfreehand(hAx(1));
	%           synROI = synchronizedImfreehands(baseROI,'ROIParentHandles',hAx);
	%           synROI.lineColor = 'r';


	%%% Properties
	properties (SetAccess=public, GetAccess=public, SetObservable)
		activeROI = imfreehand.empty(0,0)
	end
	properties (SetAccess=protected)
		ROI  = imfreehand.empty(0,1)
	end
    
	methods
		function vObj = synchronizedImfreehands(baseROI,varargin)
			% synchronizedImfreehands % CONSTRUCTOR for synchronizedImfreehands
			% -------------------------------------------------------------------------
			% Constructs a new synchronizedImfreehands
			
			%----- Create Graphics and Assign Inputs -----%
			
			% Call superclass constructor to do everything
			if isa(baseROI,'matlab.graphics.axis.Axes')
				baseROI = imfreehand(baseROI); %#ok<*IMFREEH>
            end
            % ,'labelPositionPreference','retnec'
			vObj = vObj@synchronizedROI(baseROI,varargin{:});
		end %synchronizedImfreehands (CONSTRUCTOR)
	end %methods
	
	methods %set/get
		function [] = set.ROI(obj,value)
			%validate for the right class and number of ROIs provided
			validateattributes(value,{'imfreehand'},{'nonempty'});
			obj.ROI = value;
		end %set.ROI
	end %methods %set/get
	
end