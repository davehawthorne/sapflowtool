function c = loadSapflowConfig(filename)
    % Reads the project configuration and sensor data state from an XML
    % file.  Processes the information via a DOM intermediate.
    % It either returns a structure containing the config data or throws a
    % MException with 'sapflowConfig:fileError'.
    %
    % This is the complement of ProjectFileAccess.
    try
        top = xmlread(filename);
    catch err
        if strcmp(err.identifier, 'MATLAB:Java:GenericException')
            throw(MException('sapflowConfig:fileError', 'The XML file is faulty. Error details follow:\n %s', err.message))
        end
        rethrow(err)
    end

    sfp = getOnly(top, 'SapflowProject');
    protocol = getIntegerAttribute(sfp, 'protocolVersion');
    if (protocol ~= 1)
        throw(MException('sapflowConfig:fileError', 'This version of code can only read version 1 project files; not %d', protocol))
    end

    c.project = readProjectConfig(sfp);
    c.sensors = readSensorsData(sfp);

end


function config = readProjectConfig(parent)
    node = getOnly(parent, 'ProjectConfig');
    config.projectName = getNodeStringValue(node, 'ProjectName');
    config.projectDesc = getNodeStringValue(node, 'ProjectDesc');
    config.sourceFilename = getNodeStringValue(node, 'SourceFilename');
    config.numSensors = getNodeIntegerValues(node, 'NumberSensors', 1);
    config.minRawValue = getNodeFloatValues(node, 'MinRawValue', 1);
    config.maxRawValue = getNodeFloatValues(node, 'MaxRawValue',1 );
    config.maxRawStep = getNodeFloatValues(node, 'MaxRawStep', 1);
    config.minRunLength = getNodeIntegerValues(node, 'MinRunLength', 1);
    config.parThresh = getNodeFloatValues(node, 'ParThresh', 1);
    config.vpdThresh = getNodeFloatValues(node, 'VpdThresh', 1);
    config.vpdTime = getNodeFloatValues(node, 'VpdTime', 1);
end

function sensors = readSensorsData( parent)

    nodes = parent.getElementsByTagName('Sensor');

    sensors = cell(1, nodes.getLength());

    for i = 1:nodes.getLength()
        node = nodes.item(i-1);
        num = getIntegerAttribute(node, 'number');

        sensor.bla = getNodeIntegerValues(node, 'bla', 0);
        sensor.spbl = getNodeIntegerValues(node, 'spbl', 0);
        sensor.zvbl = getNodeIntegerValues(node, 'zvbl', 0);
        sensor.lzvbl = getNodeIntegerValues(node, 'lzvbl', 0);

        sensor.sapflow.cut = {};
        sensor.sapflow.new = {};
        sapflow = getOnly(node, 'Sapflow');
        cuts = sapflow.getElementsByTagName('Cut');
        for j = 1:cuts.getLength()
            cut = cuts.item(j-1);
            s.start = getIntegerAttribute(cut, 'start');
            s.end = getIntegerAttribute(cut, 'end');
            sensor.sapflow.cut{j} = s;
        end
        news = sapflow.getElementsByTagName('New');
        for j = 1:news.getLength()
            new = news.item(j-1);
            s.start = getIntegerAttribute(new, 'start');
            s.end = getIntegerAttribute(new, 'end');
            s.data = getNumericalValue(new);
            if length(s.data) ~= s.end - s.start + 1
                throw(MException('sapflowConfig:fileError', 'Bad new sapflow data length: can''t fit %d items in [%d:%d]', length(s.data), s.start, s.end))
            end
            sensor.sapflow.new{j} = s;
        end

        sensors{num} = sensor;
    end
end

function child = getOnly(parent, nodeName)
    children = parent.getElementsByTagName(nodeName);
    if children.getLength() ~= 1
        throw(MException('sapflowConfig:fileError', 'Expecting exactly one "%s" in node "%s", got %d', nodeName, char(parent.getNodeName()), children.getLength()));
    end
    child = children.item(0);
end

function value = getIntegerAttribute(parent, attrName)
    if not(parent.hasAttribute(attrName))
        throw(MException('sapflowConfig:fileError', 'Expected attribute "%s" missing from node "%s"', attrName, char(parent.getNodeName())));
    end
    attr = parent.getAttributeNode(attrName);
    string = attr.getValue();
    value = str2num(string); %#ok<ST2NM>
    if not((value == round(value)) && isscalar(value))
        throw(MException('sapflowConfig:fileError', 'Expected single integer for attribute "%s", not "%s"', attrName, string));
    end
end

function value = getNumericalValue(node)
    value = str2num(node.getTextContent()); %#ok<ST2NM>
end


function values = getNodeIntegerValues(parent, nodeName, maxCount)
    values = getNodeFloatValues(parent, nodeName, maxCount);
    if not(all(values == round(values)))
        throw(MException('sapflowConfig:fileError', 'Expected integers for node "%s", not floats', nodeName));
    end
end

function values = getNodeFloatValues(parent, nodeName, maxCount)
    node = getOnly(parent, nodeName);
    values = getNumericalValue(node);
    if maxCount && length(values) > maxCount
        throw(MException('sapflowConfig:fileError', 'Expected no more than %d values for node "%s", got %d', maxCount, nodeName, length(values)));
    end
end


function value = getNodeStringValue(parent, nodeName)
    node = getOnly(parent, nodeName);
    value = char(node.getTextContent());
end
