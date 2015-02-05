classdef SapflowProcessor < handle
    properties (SetAccess = private, GetAccess = public)
        doy
        tod
        vpd
        par
        ss
        ssL
        
        spbl
        zvbl
        lzvbl
        bla
        
        k_line, ka_line, nvpd
        
        cmdStack
    end
    
    properties (SetAccess = public, GetAccess = public)        
        Timestep = 15;
        PARthresh=100; % values less than threshold are considered nighttime
        % VPD
        VPDthresh=0.05; % values less than threshold are considered effectively zero
        VPDtime=2; % length in HOURS of time segment of low-VPD conditions     
        
        baselineCallback, sapflowCallback
    end
    
    methods
        function o = SapflowProcessor(doy, tod, vpd, par, ss)
            o.doy = doy;
            o.tod = tod;
            o.vpd = vpd;
            o.par = par;
            o.ss = ss;
            o.ssL = length(o.ss);
            
            o.cmdStack = Stack();
        end
        
        function o = addBaseline(o, t)
            o.cmdStack.push({'add baseline', @o.undoBaselineChange, o.bla});
            o.bla = sort([o.bla; t]);
            o.compute();
            o.baselineCallback();
        end
        
        function o = delBaseline(o, i)
            o.cmdStack.push({'delete baseline', @o.undoBaselineChange, o.bla});
            o.bla(i) = [];
            o.compute();
            o.baselineCallback();
        end
        
        function blaSaved = findAffectedBlas(o, t)
            toDelete = zeros(o.ssL);
            toDelete(t) = 1;
            i = find(toDelete(o.bla))
            blaSaved = o.bla(i)
            o.bla(i) = [];
        end
            
        
        function o = delSapflow(o, t)
            blaSaved = o.findAffectedBlas(t)
            o.cmdStack.push({'delete sapflow data', @o.undoSapflowChange, t, o.ss(t), blaSaved});
            o.ss(t) = NaN;
            o.compute();
            o.sapflowCallback();
            o.baselineCallback();
        end
        
        function o = interpSapflow(o, t)
            blaSaved = findAffectedBlas(t)
            o.cmdStack.push({'delete sapflow data', @o.undoSapflowChange, t, o.ss(t), blaSaved});
            o.ss(t) = NaN;
            o.compute();
            o.sapflowCallback();
            o.baselineCallback();
        end
        
        function o = undoBaselineChange(o, args)
            o.bla = args{1};
            o.compute();
            o.baselineCallback();
        end
        
        function o = undoSapflowChange(o, args)
            [t, orig, blaSaved] = args{1:end};
            o.ss(t) = orig;
            o.bla = sort([o.bla; blaSaved]);
            o.compute();
            o.sapflowCallback();
            o.baselineCallback();
        end
        
        function o = undo(o)
            if o.cmdStack.empty()
                return;
            end
            cmd = o.cmdStack.pop();
            func = cmd{2};
            args = cmd(3:end);
            func(args);
        end
        
        function o = auto(o)
            nDOY = o.doy;
            nDOY(o.tod < 1000) = nDOY(o.tod < 1000) - 1;

            [o.spbl, ~, o.zvbl, o.lzvbl] = BL_auto( ...
                o.ss, o.doy, nDOY, o.Timestep, o.par, o.PARthresh, ...
                o.vpd, o.VPDthresh, o.VPDtime ...
            );
        
            iValidSamples = find(isfinite(o.ss));
            iFirstValid = min(iValidSamples);
            iLastValid = max(iValidSamples);
            if iFirstValid == o.lzvbl(1)
                iFirstValid = [];
            end
            if iLastValid == o.lzvbl(end)
                iLastValid = [];
            end
            
            o.bla = [iFirstValid; o.lzvbl; iLastValid];
        end
        
        function o = compute(o)
            blv = interp1(o.zvbl, o.ss(o.zvbl), (1:o.ssL))';
            
            o.k_line = blv ./ o.ss - 1;
            o.k_line(o.k_line < 0) = 0;
            
            blv = interp1(o.bla, o.ss(o.bla), (1:o.ssL))';
            o.ka_line = blv ./ o.ss - 1;
            o.ka_line(o.ka_line < 0) = 0;
            
            o.nvpd = o.vpd ./ max(o.vpd) .* max(o.ka_line);
        end

    end
    
end    