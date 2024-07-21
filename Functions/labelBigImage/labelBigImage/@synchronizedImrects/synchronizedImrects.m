classdef synchronizedImrects < synchronizedROI
	% Syntax:
	%           vObj = synchronizedImrects()
	%           vObj = synchronizedImrects('p1',v1,...)
	%
	% Inputs:
	%           Optional property-value pairs for default synchronizedROI
	%
	% Outputs:
	%           vObj - synchronizedImrects object
	%
	% % Example:
	%
	%           hAx(1) = subplot(1,2,1);
	%           hAx(2) = subplot(1,2,2);
	%           title('DRAW HERE!','parent',hAx(1));
	%           baseROI = imrect(hAx(1));
	%           synROI = synchronizedImrects(baseROI,'ROIParentHandles',hAx);
	%           synROI.lineColor = 'r';

	%%% Properties
	properties (SetAccess=public, GetAccess=public, SetObservable)
		activeROI = imrect.empty(0,0)
	end
	properties (SetAccess=protected)
		ROI  = imrect.empty(0,1)
	end
	methods
		function vObj = synchronizedImrects(baseROI,varargin)
			% synchronizedImrects % CONSTRUCTOR for synchronizedImrects
			% -------------------------------------------------------------------------
			% Constructs a new synchronizedImrects
			
			%----- Create Graphics and Assign Inputs -----%
			
			% Call superclass constructor to do everything
			if isa(baseROI,'matlab.graphics.axis.Axes')
				baseROI = imrect(baseROI); %#ok<*IMRECT>
			end
			vObj = vObj@synchronizedROI(baseROI,varargin{:});
		end %synchronizedImfreehands (CONSTRUCTOR)
	end %methods
	
	methods %set/get
		function [] = set.ROI(obj,value)
			%validate for the right class and number of ROIs provided
			validateattributes(value,{'imrect'},{'nonempty'});
			obj.ROI = value;
		end %set.ROI
       
	end %methods %set/get
	
    methods (Access=protected)
        function [] = setActiveROIPosition(obj,positionArr)
%             positionArr = obj.activeROI.getPosition(); %[x y w h]
            points = bbox2points(positionArr);
            setActiveROIPosition@synchronizedROI(obj,points);
        end
        %===========================================================%
        function [value] = getROIPositions(obj)
            value = cell(obj.numROIs,1);
            for i = 1:numel(obj.ROIPositions)
                points = obj.ROIPositions{i};
                x = min(points(:,1));
                y = min(points(:,2));
                w = max(points(:,1)) - x;
                h = max(points(:,2)) - y;
                value{i}  = [x y w h];
            end
        end  
      %===========================================================%
       function [] = setROIPositions(obj,value)
           assert(isequal(numel(value),obj.numROIs));
           for i = 1:obj.numROIs
               if(~isempty(value{i}))
                   points = bbox2points(value{i});
                   value{i} = points;
               end
           end
           obj.ROIPositions = value;
       end
    end
    % methods (Access=public)
    % 		function [] = extendContextMenus(obj)
% 			for ii = 1:obj.numROIs
% 				extendImroiContextMenu(obj.ROI(ii))
% 			end
% 		end
% 	
% 		function [] = addSynchronizedLabels(obj,varargin)
% 			addSynchronizedLabelToImrois(obj,varargin{:})
% 		end
% 	end %methods (Access=public)
% 	
	
	
end