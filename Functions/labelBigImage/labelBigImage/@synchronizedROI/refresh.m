function refresh(vObj,evt)
    % Call the callback, providing relevant eventdata
	e = struct('Source',vObj);
    e.Interaction = evt;
    vObj.callCallback(e);
end