classdef synchronizedImpolys < synchronizedROI
	% Syntax:
	%           vObj = synchronizedImpolys()
	%           vObj = synchronizedImpolys('p1',v1,...)
	%
	% Inputs:
	%           Optional property-value pairs for default synchronizedROI
	%
	% Outputs:
	%           vObj - synchronizedImpolys object
	%
	% % Example:
	%
	%           hAx(1) = subplot(1,2,1);
	%           hAx(2) = subplot(1,2,2);
	%           title('DRAW HERE!','parent',hAx(1));
	%           baseROI = impoly(hAx(1));
	%           synROI = synchronizedImpolys(baseROI,'ROIParentHandles',hAx);
	%           synROI.lineColor = 'r';

	%%% Properties
	properties (SetAccess=public, GetAccess=public, SetObservable)
		activeROI = impoly.empty(0,0)
	end
	properties (SetAccess=protected)
		ROI  = impoly.empty(0,1)
	end
	methods
		function vObj = synchronizedImpolys(baseROI,varargin)
			% synchronizedImpolys % CONSTRUCTOR for synchronizedImpolys
			% -------------------------------------------------------------------------
			% Constructs a new synchronizedImpolys
			
			%----- Create Graphics and Assign Inputs -----%
			
			% Call superclass constructor to do everything
			if isa(baseROI,'matlab.graphics.axis.Axes')
				baseROI = impoly(baseROI);
			end
			vObj = vObj@synchronizedROI(baseROI,varargin{:});
		end %synchronizedImpolys (CONSTRUCTOR)
	end %methods
	
	methods %set/get
		function [] = set.ROI(obj,value)
			%validate for the right class and number of ROIs provided
			validateattributes(value,{'impoly'},{'nonempty'});
			obj.ROI = value;
		end %set.ROI
	end %methods %set/get	
	
end