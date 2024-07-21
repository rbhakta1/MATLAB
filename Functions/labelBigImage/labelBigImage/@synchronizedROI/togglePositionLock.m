function togglePositionLock(synchronizedROIObject,varargin)
if synchronizedROIObject.isLocked
	% Unlock:
	tmpFcn = @(varargin)deal(varargin{:});
	for ll = 1:synchronizedROIObject.numROIs
		setPositionConstraintFcn(synchronizedROIObject.ROI(ll),tmpFcn);
	end
	synchronizedROIObject.lineStyle = '-';
	synchronizedROIObject.isLocked = false;
else
	% Lock:
	for ll = 1:synchronizedROIObject.numROIs
		setPositionConstraintFcn(synchronizedROIObject.ROI(ll),...
			@(pos)synchronizedROIObject.ROI(ll).getPosition());
	end
	synchronizedROIObject.lineStyle = '-.';
	synchronizedROIObject.isLocked = true;
	%synchronizedROIObject.lineColor = 'b';
end

end %lockUnlockPositions
