function c = loadSapflowConfig(filename)
    top = xmlread(filename);
    sfp = getOnly(top, 'SapflowProject');

    config = getOnly(sfp, 'ProjectConfig');
    node = getOnly(config, 'ProjectName');
    c.project.projectDesc = char(node.getTextContent());
    node = getOnly(config, 'SourceFilename');
    c.project.sourceFilename = char(node.getTextContent());
    node = getOnly(config, 'NumberSensors');
    c.project.numSensors = getNumericalValue(node);

    c.sensors = {};

    sensors = sfp.getElementsByTagName('Sensor');
    %TEMP!!! c = cell(1, sensors.getLength());
    for i = 1:sensors.getLength()
        sen = sensors.item(i-1);
        num = getNumericAttribute(sen, 'number');

        c.sensors{num}.bla = getNumericalValue(getOnly(sen, 'bla'));
        c.sensors{num}.spbl = getNumericalValue(getOnly(sen, 'spbl'));
        c.sensors{num}.zvbl = getNumericalValue(getOnly(sen, 'zvbl'));
        c.sensors{num}.lzvbl = getNumericalValue(getOnly(sen, 'lzvbl'));

        c.sensors{num}.sapflow.cut = cell(1,0);
        c.sensors{num}.sapflow.new = cell(1,0);
        sapflow = getOnly(sen, 'Sapflow');
        cuts = sapflow.getElementsByTagName('Cut');
        %TEMP!!! c.sensors{num}.sapflow.cut = cell(1, cuts.getLength());
        for j = 1:cuts.getLength()
            cut = cuts.item(j-1);
            c.sensors{num}.sapflow.cut{j}.start = getNumericAttribute(cut, 'Start');
            c.sensors{num}.sapflow.cut{j}.end = getNumericAttribute(cut, 'End');
        end
        news = sapflow.getElementsByTagName('New');
        for j = 1:news.getLength()
            new = news.item(j-1);
            c.sensors{num}.sapflow.new{j}.start = getNumericAttribute(new, 'Start');
            c.sensors{num}.sapflow.new{j}.end = getNumericAttribute(new, 'End');
            c.sensors{num}.sapflow.new{j}.data = getNumericalValue(new);
        end

    end
end

function child = getOnly(parent, nodeName)
    children = parent.getElementsByTagName(nodeName);
    if children.getLength() ~= 1
        error(sprintf('Expecting exactly one "%s" in "%s", got %d', nodeName, char(parent.getNodeName()), children.getLength()))
    end
    child = children.item(0);
end

function value = getNumericAttribute(parent, attrName)
    if not(parent.hasAttribute(attrName))
        error('Expected attribute "%s" missing from "%s"', attrName, char(parent.getNodeName()))
    end
    attr = parent.getAttributeNode(attrName);
    value = str2num(attr.getValue());
end

function value = getNumericalValue(node)
    value = str2num(node.getTextContent());
end

