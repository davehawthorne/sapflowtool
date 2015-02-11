classdef ConfigSaver < handle
    % This is a disaster; xlsread and xlswrite are painfully slow.
    % We'll either need to use ActiveX with Excel or switch to XML
    properties (Access = private)
        filename
    end


    properties (Access = private, Constant)
        sensorTemplate = {
            'edited'   []      []     []      []       []  'sapflow edits';
            []         []      []     []      []       []  []      ;
            'baseline' 'spbl' 'zvbl' 'lzvbl' 'bla'     []  'start' ;
            'count'    []      []     []      []       []  'end'   ;
            []         []      []     []      []       []  []      ;
            'times'    []      []     []      []       []  'data'  ;
        };
    end

    properties (Access = public, Constant)
        ConfigFilenameMask = '*.xls'
    end

    methods
        function o = ConfigSaver(filename)
            o.filename = filename;
        end

        function s = readAll(o)
            s = o.readMaster();
            s.sensor = cell(1,s.numSensors);
            for i = 1:s.numSensors
                s.sensor{i} = o.readSensor(i);
            end
        end


        function s = readMaster(o)
            [~, ~, raw] = xlsread(o.filename, 'master');
            s.sourceFilename = raw{1,2};
            s.numSensors = raw{4,2};
        end

        function writeSensor(o, num, s)
            ca = ConfigSaver.sensorTemplate;
            ca{1, 2} = datestr(datetime);
            names = ConfigSaver.sensorTemplate(3, 2:5);
            for i = 1:4
                col = i + 1;
                name = names{i};
                data = s.(name);
                len = length(data);

                ca{4, col} = len;
                ca(6:5+len, col) = num2cell(data);
            end

            [numSegs, ~] = size(s.ss);
            ca{1, 8} = numSegs;
            for i = 1:numSegs
                col = i + 7;
                data = s.ss{i,3};
                len = length(data);
                [tStart, tEnd] = s.ss{i,1:2};
                ca{3,col} = tStart;
                ca{4,col} = tEnd;
                ca(6:5+len,col) = num2cell(data);
            end

            sheetName = sprintf('s%d', num);

            xlswrite(o.filename, ca, sheetName);
        end


        function s = readSensor(o, num)
            sheetName = sprintf('s%d', num);
            try
                [~, ~, raw] = xlsread(o.filename, sheetName);
            catch e
                disp(e)
                s = [];
                return
            end

            st = ConfigSaver.sensorTemplate;
            [rows, cols] = size(st);
            for r = 1:rows
                for c = 1:cols
                    if iscellstr(st(r,c)) && not(strcmp(st{r,c}, raw{r,c}))
                        fprintf('row %d col %d: "%s" != "%s"', r, c, st{r,c}, raw{r,c});
                        return
                    end
                end
            end

            s = struct();

            names = ConfigSaver.sensorTemplate(3, 2:5);

            for i = 1:4
                col = i + 1;
                name = names{i};
                len = raw{4, col};
                s.(name) = oneByN(cell2mat(raw(6:5+len, col)));
            end
            numSegs = raw{1, 8};
            s.ss = cell(numSegs, 3);
            for i = 1:numSegs
                col = i + 7;
                tStart = raw{3, col};
                tEnd = raw{4, col};
                len = tEnd - tStart + 1;
                data = cell2mat(raw(6:5+len, col));
                s.ss(i,:) = {tStart, tEnd, data};
            end

        end
    end
end


