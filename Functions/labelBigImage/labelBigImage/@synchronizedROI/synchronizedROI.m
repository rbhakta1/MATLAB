classdef (Abstract) synchronizedROI < matlab.mixin.SetGet & uix.mixin.AssignPVPairs & uix.mixin.HasCallback
	% synchronizedROI - Class definition for synchronizedROI abstract class. This
	% class consists of two ROI objects
	% ---------------------------------------------------------------------
	% Abstract: Display a viewer/editor for a synchronizedROI object
	%
	% Syntax:
	%           vObj = synchronizedROI
	%           vObj = synchronizedROI('Property','Value',...)
	%
	% synchronizedROI properties:
	%     ROI1 - imroi abstract
	%     ROI1ParentHandle - handle to the parent axes of ROI1
	%     ROI2  - imroi abstract
	%     ROI2ParentHandle - handle to the parent axes of ROI2
	%     ROI1ImagePars - ROI1 image position parameters [w h centx centy]
	%     ROI2ImagePars - ROI2 image position parameters [w h centx centy]
	%     ROIActive - [true false] boolean flags indicating which is the active ROI
	%     referenceObjects - An imref2d object, or vector thereof,
	%        mapping from the "intrinsic" to the "world" axes coordinates.
	%     Callback - A settable callback that will fire when the
	%        synchronizedROI's Data is modified.
	%
	%
	% synchronizedROI methods:
	%
	%     callCallback - call a user-specified callback function
	%
	%   Callback methods:
	%
	% Examples:
	%  vObj = synchronizedROI()
	
	% Copyright 2014-2017 The MathWorks, Inc.
	%
	% Auth/Revision:
	%   MathWorks Consulting
	%   $Author: joyeetam $
	%   $Revision: 12 $  $Date: 2017-08-25 16:51:03 -0400 (Fri, 25 Aug 2017) $
	%
	% And:
	% Brett Shoelson, PhD
	% brett.shoelson@mathworks.com
	% ---------------------------------------------------------------------
	
	
	%% Properties
	properties (SetAccess=public, GetAccess=public)
		autoLockWhenLabeled  = false
        backgroundColor = [0 0.8 0]
        labelPositionPreference  = 'Top' %{'Top','Center','Bottom'}
        lineColor = [0.28235 0.28235 0.97255]
		lineStyle = '-'
		lineWidth = 0.75
        parent
		referenceObjects imref2d
		samplingOpts struct
		score
        uniqueIdentifier
		userData
        validated
	end
	properties (SetObservable)
		allowUnlabeled = true 
        boundingBox
		defaultLabel     char
		isClosed = true
		isLocked = false;
		label            char % Label; set via addSynchronizedLabel
		labelButtons
		labelList
		outputVarname char
		referenceMode    char % absolute or relative
		regionDescriptors struct
		ROIParentHandles   % axes handle array of dim numROIs X 1, representing the image axes on which the ROIs are placed		
	end
	properties (Dependent)
        idxActiveROI = 0
		numROIs uint8
	end
	properties (Abstract, SetAccess=protected)
		ROI 
    end
    properties (Abstract, SetAccess=public, GetAccess=public, SetObservable)
		activeROI 
	end
	properties(SetAccess=protected)
		ROIPositions % cell array of current ROI positions    
		buttonUpCallbackID
	end
	properties (SetAccess=private, GetAccess=private)
		CallBackId struct
		labelMotionCallbackID struct
		sampleImageCallbackID struct
	end
	%% Constructor and Destructor
	% A constructor method is a special function that creates an instance
	% of the class. Typically, constructor methods accept input arguments
	% to assign the data stored in properties and always return an
	% initialized object.
	methods
		function vObj = synchronizedROI(baseROI,varargin)
			% synchronizedROI % CONSTRUCTOR for synchronizedROI
			% -------------------------------------------------------------------------
			% Abstract: Constructs a new synchronizedROI
			%
			% Syntax:
			%           vObj = synchronizedROI()
			%           vObj = synchronizedROI('p1',v1,...)
			%
			% Inputs:
			%           Optional property-value pairs for default synchronizedROI
			%
			% Outputs:
			%           vObj - synchronizedROI object
			%
			% Examples:
			%           vObj = synchronizedROI();
			%
			%----- Create Graphics and Assign Inputs -----%
			
            % Populate public properties from P-V input pairs
            vObj.assignPVPairs(varargin{:});
            if isempty(vObj.referenceMode)
                vObj.referenceMode = 'relative'; %DEFAULT
            end
            if ~isempty(baseROI)
                %Otherwise, request was canceled!
                gObj = hggroup;
                vObj.create(baseROI);
                switch class(baseROI)
                    % Note: impoint is zero width if vertToPos is used; to
                    %       change to W, H=1, uncomment code below.
                    case {'imfreehand','impoly','imline','impoint'}
                        vObj.boundingBox = vertToPos(baseROI.getPosition);
                    case 'imrect'
                        vObj.boundingBox = baseROI.getPosition;
                    %case 'impoint'
                    %    vObj.boundingBox = [baseROI.getPosition, 1, 1];
                end
                set(gObj,'parent',vObj.ROIParentHandles(1));
                set(vObj,'parent',gObj);
                set(gObj,'Tag',class(vObj));
                set(gObj,'UserData',vObj);
            end
        end %synchronizedROI (CONSTRUCTOR)
	end %methods
    %% Set / Get
    methods %set / get
        %===========================================================%
        function [value] = get.idxActiveROI(obj)
            value = 0; %default
            if(~isempty(obj.activeROI))
                idxROI = find(obj.ROI==obj.activeROI);
                if isempty(idxROI)
                    hParent = get(obj.activeROI,'parent');
                    idxROI = find(obj.ROIParentHandles==hParent);
                end
                value = idxROI;
            end %get.numROIs
        end
		%===========================================================%
        function [] = set.backgroundColor(obj,value)
            obj.backgroundColor = value;
            obj.backgroundColor();
            obj.setBackgroundColor();
        end %set.lineColor
		%===========================================================%
        function [] = set.lineColor(obj,value)
            obj.lineColor = value;
            obj.setLineColor();
        end %set.lineColor
        %===========================================================%
        function [] = set.lineStyle(obj,value)
            obj.lineStyle = value;
            obj.setLineStyle();
        end %set.lineStyle
        %===========================================================%
        function [] = set.lineWidth(obj,value)
            obj.lineWidth = value;
            obj.setLineWidth();
        end %set.lineWidth
        %===========================================================%
        function [value] = get.numROIs(obj)
            value = numel(obj.ROIParentHandles);
        end %get.numROIs
        %===========================================================%
        function [] = set.referenceMode(obj,value)
            validateattributes(value,{'string','char'},{'nonempty'});
            validatestring(lower(value),{'relative','absolute'});
            obj.referenceMode = lower(value);
        end %set.ROIPositions
		%===========================================================%
		function [] = set.ROIParentHandles(obj,value)
			%validate for the right class and number of ROIs provided
			validateattributes(value,{'matlab.graphics.axis.Axes'},{'nonempty'});
			obj.ROIParentHandles = value;
		end %set.ROIParentHandles
		%===========================================================%
		function [] = set.samplingOpts(obj,value)
			validateattributes(value,{'struct'},{'nonempty'});
			obj.samplingOpts = value;
		end %set.samplingOpts
		%===========================================================%
		function [] = set.userData(obj,value)
			obj.userData = value;
		end %set.userData
		%===========================================================%
        function setLabelPositionPreference(obj,pref,varargin)
            obj.labelPositionPreference
            %I DON'T KNOW WHY THIS ISN'T UPDATING!!! BDS todo (JOYEETA?)
            
            obj.labelPositionPreference = pref;
        end %setLabelPositionPreference

    end %methods %set / get
	
	%% Public Methods
    methods (Access=public)
	   %===========================================================%
	   function [] = deleteROISet(obj)
		   delete(obj.ROI)
		   delete(obj.labelButtons)
		   % hggroup
		   delete(obj.parent);
	   end %deleteROISet
	   %===========================================================%
		refresh(obj,Interaction);
    end
	%% Protected methods
	methods (Access=protected)
        create(obj,baseROI);
        redraw(obj);
        %===========================================================%
        function [positions] = getROIPositions(obj)
            positions = obj.ROIPositions;
        end
		%===========================================================%
		function [] = getSynchronizedROIPosition(obj, currInd, idxROIActive)
			positionActive = obj.ROIPositions{idxROIActive};
			if strcmp(obj.referenceMode,'relative') && ~isempty(obj.referenceObjects) && ...
					currInd ~= idxROIActive
				thisRefObj = obj.referenceObjects(idxROIActive,currInd);
				positionCurrROI = obj.mapROIs(positionActive,...
					thisRefObj);
			else
				positionCurrROI = positionActive;
			end
			obj.ROIPositions{currInd} = positionCurrROI;
		end %getSynchronizedROIPosition
		%===========================================================%
		function [] = setActiveROIPosition(obj, position)
            obj.ROIPositions{obj.idxActiveROI} = position;
        end
        %===========================================================%
        function [] = setROIPositions(obj,value)
            validateattributes(value,{'cell'},{'vector'});
            obj.ROIPositions = value;
        end
        %===========================================================%
        function [Message, StatusOk] = setSynchronizedROIPosition(obj)
            StatusOk = true;
			Message = [];
			idxROI = obj.idxActiveROI;
			if(numel(idxROI)>1)
				Message = 'Only one ROI can be active';
				StatusOk = false;
				return;
			end
			if ( (numel(obj.ROIParentHandles) ~= obj.numROIs) )
				Message = 'Number of ROIs must match the number of image axes ';
				StatusOk = false;
				return;
			end
			%loop over the number of ROIs , one per axes and get positions
			%of each ROI, store in the ROIPositions array
			for ii = 1:obj.numROIs
				if(ii~=idxROI)
					obj.getSynchronizedROIPosition(ii,idxROI);
				end
			end
		end %setSynchronizedROIPosition
		%===========================================================%
		function setLineColor(obj)
			for ii = 1:numel(obj.ROI)
				obj.ROI(ii).setColor(obj.lineColor);
			end
		end %setLineColor
		%===========================================================%
		function setLineStyle(obj)
			for ii = 1:numel(obj.ROI)
				l = findall(obj.ROI(ii),'type','line');
				set(l,'LineStyle',obj.lineStyle);
			end
		end %setLineStyle
		%===========================================================%
        function setBackgroundColor(obj)
            if ~isempty(obj.labelButtons)
                for ii = 1:numel(obj.ROI)
                    lb = obj.labelButtons(ii);
                    set(lb,'BackgroundColor',obj.backgroundColor);
                end
            end
		end %setLineStyle
		%===========================================================%
		function setLineWidth(obj)
			for ii = 1:numel(obj.ROI)
				l = findall(obj.ROI(ii),'type','line');
				set(l,'LineWidth',obj.lineWidth)
			end
		end %setLineWidth
		%===========================================================%
		function setReferenceMode(obj)
			obj.referenceMode
		end %setReferenceMode
		%===========================================================%
%         function setLabelPositionPreference(obj,pref,varargin)
%             obj.labelPositionPreference
%             %I DON'T KNOW WHY THIS ISN'T UPDATING!!! BDS todo
%             obj.labelPositionPreference = pref;
%         end %setLabelPositionPreference
        
    end %methods (Access=protected)
    %% Private Methods
	methods (Access = private)
		function [] = setActiveROI(obj,pos,h)
			obj.activeROI = h; %this is the active ROI now
			obj.setActiveROIPosition(pos); %update position
            obj.redraw();
		end %setActiveROI
	end 
	%% Static Methods
	methods (Static, Access = private)%(Abstract, Static)
		extendSynchronizedImroiContextMenu(roi);
		matchImfreehandPosition(h,hRef,refObj);
		function [positionROI] = mapROIs(positionActive,imreferencingObject)
			% Function for mapping positions of synchronized ROIs
			if nargin < 2 || isempty(imreferencingObject)
				positionROI = positionActive;
			else
				[row,col] = intrinsicToWorld(imreferencingObject,...
					positionActive(:,1),positionActive(:,2));
				positionROI = [row,col];
			end
		end %mapROIs
	end
	
end %classdef