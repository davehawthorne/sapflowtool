classdef ProjectFileAccess < handle
    properties (Access = private)
        docNode
    end
    properties (GetAccess = public, SetAccess = private)
        docRootNode
    end
    methods
        function o = ProjectFileAccess()
            o.docNode = com.mathworks.xml.XMLUtils.createDocument('SapflowProject');
            o.docRootNode = o.docNode.getDocumentElement;
        end

        function element = addElement(o, parent, nodeName, nodeValue)
            element = o.docNode.createElement(nodeName);
            textNode = o.docNode.createTextNode(nodeValue);
            element.appendChild(textNode);
            parent.appendChild(element);
        end

        function save(o, filename)
            xmlwrite(filename, o.docNode);
        end


        function writeConfig(o, s)
            element = o.docNode.createElement('ProjectConfig');
            o.addElement(element, 'SourceFilename', s.sourceFilename);
            o.addElement(element, 'ProjectName', s.projectDesc);
            o.addElement(element, 'NumberSensors', num2str(s.numSensors));
            o.docRootNode.appendChild(element);
        end

        function writeSensor(o, num, s)
            element = o.docNode.createElement('Sensor');
            element.setAttribute('number', num2str(num));
            o.addElement(element, 'spbl', sprintf('%d ', s.spbl));
            o.addElement(element, 'zvbl', sprintf('%d ', s.zvbl));
            o.addElement(element, 'lzvbl', sprintf('%d ', s.lzvbl));
            o.addElement(element, 'bla', sprintf('%d ', s.bla));
            sapflow = o.docNode.createElement('Sapflow');

            for seg = s.sapflow.cut
                segv = seg{1};
                sel = o.docNode.createElement('Cut');
                sel.setAttribute('Start', num2str(segv.start));
                sel.setAttribute('End', num2str(segv.end));
                sapflow.appendChild(sel);
            end
            for seg = s.sapflow.new
                segv = seg{1};
                sel = o.docNode.createElement('New');
                sel.setAttribute('Start', num2str(segv.start));
                sel.setAttribute('End', num2str(segv.end));
                textNode = o.docNode.createTextNode(sprintf('%f ', segv.data));
                sel.appendChild(textNode);
                sapflow.appendChild(sel);
            end
            element.appendChild(sapflow);
            o.docRootNode.appendChild(element);
        end
    end
end
