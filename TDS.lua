-- The indicator is Richard Tao Adaptive DeMark Indicator Analysis 
-- The DeMark Indicator is registered by Tom DeMark, all rights are reserved.

-- initializes the indicator
function Init()
    indicator:name("RichardTaoTDIndicator");
    indicator:description("Richard Tao Adaptive DeMark Sequential.");
    indicator:requiredSource(core.Bar);
    indicator:type(core.Indicator);
    indicator:setTag("group", "Tao");

    indicator.parameters:addGroup("Calculation");
    indicator.parameters:addInteger("S", "Setup Interval", "", 4);
    indicator.parameters:addInteger("C", "Countdown Interval", "", 2);
    indicator.parameters:addInteger("N", "Number of MA periods", "", 20);
    indicator.parameters:addBoolean("ShowSeq", "Show Sequential", "", true);   
    indicator.parameters:addGroup("Style");
    indicator.parameters:addInteger("StopStyle", "Stop Level Line Style", "", core.LINE_SOLID);
    indicator.parameters:setFlag("StopStyle", core.FLAG_LINE_STYLE);
    indicator.parameters:addColor("clrBSET", "BuySetupsColor", "", core.rgb(0, 255, 0));
    indicator.parameters:addColor("clrSSET", "SellSetupsColor", "", core.rgb(255, 128, 0));
    indicator.parameters:addColor("clrBCOUNT", "BuyCountdownsColor", "", core.rgb(0, 64, 0));
    indicator.parameters:addColor("clrSCOUNT", "SellCountdownsColor", "", core.rgb(128, 0, 0));
end

--global serial
local source = nil;
local SMA = nil;
local EMA = nil;

local BSU = nil;
local SSU = nil;
local BCD = nil;
local SCD = nil;
local BSL = nil;
local SSL = nil;


-- initializes the instance of the indicator
function Prepare()
    source = instance.source;
    local name = profile:id() .. "(" .. source:name() .. ")";
    instance:name(name);
    
    if instance.parameters.ShowSeq then 
        SMA = instance:addInternalStream(0, 0);
        EMA = instance:addInternalStream(0, 0);
        BSU = instance:createTextOutput("BSU", "BSU", "Arial", 8, core.H_Center, core.V_Bottom, instance.parameters.clrBSET, 0);
        SSU = instance:createTextOutput("SSU", "SSU", "Arial", 8, core.H_Center, core.V_Top, instance.parameters.clrSSET, 0);
        BCD = instance:createTextOutput("BCD", "BCD", "Arial", 8, core.H_Center, core.V_Bottom, instance.parameters.clrBCOUNT, 0);
        SCD = instance:createTextOutput("SCD", "SCD", "Arial", 8, core.H_Center, core.V_Top, instance.parameters.clrSCOUNT, 0);
        BSL = instance:addStream("BS", core.Line, name .. ".BS", "BS", instance.parameters.clrBCOUNT, 0);
        SSL = instance:addStream("SS", core.Line, name .. ".SS", "SS", instance.parameters.clrSCOUNT, 0);
        BSL:setStyle(instance.parameters.StopStyle);
        SSL:setStyle(instance.parameters.StopStyle);
    end
end

local oSeq = {};
local sunit = 0;
local emac = 0;

-- calculate the value
function Update(period, mode)
    if period == source:first() then
        sMax = core.max(source.high, core.range(source:first(), source:size() - 1));
        sMin = core.min(source.low, core.range(source:first(), source:size() - 1));
        sunit = (sMax - sMin) / (source:size()-1);
        oSeq = ResetSeqinfo(oSeq, 0);
        if EMA ~= nil then
            emac = 2.0 / (instance.parameters.N + 1.0);
            EMA[period] = (1 - emac) * source.close[period] + emac * source.close[period];
        end
    end

    if source:hasData(period-oSeq.SInterval) and (mode ~= core.UpdateLast) then
        if instance.parameters.ShowSeq then 
            if oSeq.SSeek <= 0 then
                oSeq = SetSetup(source, BSU, oSeq, -1, period);
            end
            if oSeq.SSeek >= 0 then
                oSeq = SetSetup(source, SSU, oSeq, 1, period);
            end
            if oSeq.Completed == -1 or oSeq.CRevSetup== 1 then
                oSeq = SetCountdown(source, BCD, oSeq, -2, period);
            end
            if oSeq.Completed == 1 or oSeq.CRevSetup== -1 then
                oSeq = SetCountdown(source, SCD, oSeq, 2, period);
            end
            if period > source:first() then
                EMA[period] = (1 - emac) * EMA[period-1] + emac * source.close[period];
            end
            if period > source:first()+instance.parameters.N then
                SMA[period] = core.avg(source.close, core.rangeTo(period, instance.parameters.N));
                if core.crossesOver(EMA, SMA, period) then
	                BCD:set(period, source.low[period]+sunit*4*-1, "F");
                end
                if core.crossesUnder(EMA, SMA, period) then
	                SCD:set(period, source.high[period]+sunit*4, "F");
                end
            end
        end
    end
    
    if (period == source:size() - 1) and (mode ~= core.UpdateLast) then
        if instance.parameters.ShowSeq then 
            --draw stop level
            local psl = math.max(oSeq.PreSEnd, oSeq.PreCEnd);
            psl = math.min(psl, period-3);

            if oSeq.Completed < 0 then
                core.drawLine(BSL, core.range(psl,period), oSeq.Stoplevel, psl, oSeq.Stoplevel, period); 
            elseif oSeq.Completed > 0 then
                core.drawLine(SSL, core.range(psl,period), oSeq.Stoplevel, psl, oSeq.Stoplevel, period); 
            end
        end
	end
end

function ResetSeqinfo(oSeq, sc)
    if sc == 0 then
        oSeq.SInterval = instance.parameters.S;
        oSeq.CInterval = instance.parameters.C;
        oSeq.Completed = 0;
        oSeq.PreSEnd = 0;
        oSeq.PreCEnd = 0;
        oSeq.Stoplevel = 0;
    end
    if sc == 0 or sc == 1 then
        oSeq.SSeek = 0;
        oSeq.Setup = 0;
        oSeq.SStart = 0;
        oSeq.SEnd = 0;
        oSeq.SPerfect = 0;
    end
    if sc == 0 or sc == 2 then
        oSeq.CSeek = 0;
        oSeq.Countdown = 0;
        oSeq.CStart = 0;
        oSeq.CEnd = 0;
        oSeq.CQualifier = 0;
        oSeq.CRevlevel = 0;
        oSeq.ConsSetup = 0;
        oSeq.CRevSetup = 0;
    end
    return oSeq;
end

function SetSetup(source, tStream, oSeq, inSeq, period)
    local hilo;
    if inSeq < 0 then
        hilo = source.low;
    else
        hilo = source.high;
    end
    local spos = hilo[period]+sunit*3*inSeq;
    
    if oSeq.Setup == 0 then
        --init find start
        if (source.close[period]-source.close[period-oSeq.SInterval])*inSeq > 0 then
            oSeq.SSeek = inSeq;
            oSeq.Setup = 1;
            oSeq.SStart = period;
            oSeq.SEnd = period;
	        tStream:set(period, spos, tostring(oSeq.Setup));
        end
    elseif oSeq.SEnd == period-1 then
        --follow check consecutive
        if (source.close[period]-source.close[period-oSeq.SInterval])*oSeq.SSeek > 0 then
            oSeq.Setup = oSeq.Setup+1;
            oSeq.SEnd = period;
	        tStream:set(period, spos, tostring(oSeq.Setup));
	        if oSeq.Setup == 7 then
	            if oSeq.SSeek < 0 then
	                oSeq.SPerfect = core.min(hilo, core.range(period-1, period));
	            else
	                oSeq.SPerfect = core.max(hilo, core.range(period-1, period));
	            end
	        end
	        if oSeq.Setup > 7 then
                if (hilo[period]-oSeq.SPerfect)*oSeq.SSeek <= 0 then tStream:set(period, spos, "0") end
	        end
	        if oSeq.Setup == 9 then
	            --get cancel level
	            if oSeq.SSeek < 0 then
	                oSeq.CRevlevel = core.max(source.high, core.range(oSeq.SStart, period));
	            else
	                oSeq.CRevlevel = core.min(source.low, core.range(oSeq.SStart, period));
	            end
                --check consecutive 2 setups
                if (period - oSeq.PreSEnd) > 9 then
                    oSeq.ConsSetup = 1;
                else
                    oSeq.ConsSetup = 2;
                end
                --check reverse setup
                if (oSeq.SSeek-oSeq.Completed) == -2 then
                    oSeq.CRevSetup = -1; 
                elseif (oSeq.SSeek-oSeq.Completed) == 2 then 
                    oSeq.CRevSetup = 1; 
                end
	            --get stop level
	            if oSeq.SSeek < 0 then
	                oSeq.Stoplevel = core.min(hilo, core.range(oSeq.SStart, period))
	                +(source.close[period]-source.high[period]);
	            else
	                oSeq.Stoplevel = core.max(hilo, core.range(oSeq.SStart, period))
	                +(source.close[period]-source.low[period]);
	            end
                
	            --set previous complete flag
                oSeq.PreSEnd = period;
                oSeq.Completed = oSeq.SSeek;
                oSeq = ResetSeqinfo(oSeq, 1);
	        end
        else
            --failed to clear this seq
            for i=oSeq.SStart, period do tStream:setNoData(i) end
            oSeq = ResetSeqinfo(oSeq, 1);
        end
    end
    return oSeq;
end

function SetCountdown(source, tStream, oSeq, inSeq, period)
    local hilo;
    if inSeq < 0 then
        hilo = source.low;
    else
        hilo = source.high;
    end
    local spos = hilo[period]+sunit*6*inSeq;
    
    local bCancel = false;
    --failed to complete
    if oSeq.CRevSetup == 0 then
        if (hilo[period]-oSeq.CRevlevel)*oSeq.CSeek < 0 and (source.close[period-1]-oSeq.CRevlevel)*oSeq.CSeek < 0 then
            bCancel = true;
        end
        if (oSeq.ConsSetup) > 1 then
            bCancel = true;
        end
    else
        if (oSeq.CRevSetup*inSeq) < 0 then
            bCancel = true;
        end
    end
    if bCancel then
        for i=oSeq.CStart, period do tStream:setNoData(i) end
        oSeq = ResetSeqinfo(oSeq, 2);
    
    elseif oSeq.Countdown == 0 then
        --init find start
        if (source.close[period]-hilo[period-oSeq.CInterval])*inSeq >= 0 then
            oSeq.CSeek = inSeq;
            oSeq.Countdown = 1;
            oSeq.CStart = period;
            oSeq.CEnd = period;
	        tStream:set(period, spos, tostring(oSeq.Countdown));
        end
    else
        --follow 
        if (source.close[period]-hilo[period-oSeq.CInterval])*oSeq.CSeek >= 0 then
            oSeq.Countdown = oSeq.Countdown+1;
            oSeq.CEnd = period;
	        tStream:set(period, spos, tostring(oSeq.Countdown));
	        if oSeq.Countdown == 8 then
	            oSeq.CQualifier = source.close[period];
	        end
	        if oSeq.Countdown > 12 then
                if (hilo[period]-oSeq.CQualifier)*oSeq.CSeek < 0 then 
                    tStream:set(period, spos, "+");
                    oSeq.Countdown = 12;
                end
	        end
	        if oSeq.Countdown == 13 then
	            --get stop level
	            if oSeq.CSeek < 0 then
	                oSeq.Stoplevel = core.min(hilo, core.range(oSeq.CStart, period))
	                +(source.close[period]-source.high[period]);
	            else
	                oSeq.Stoplevel = core.max(hilo, core.range(oSeq.CStart, period))
	                +(source.close[period]-source.low[period]);
	            end
	            --set previous complete flag
                oSeq.PreCEnd = period;
                oSeq.Completed = oSeq.CSeek;
                oSeq = ResetSeqinfo(oSeq, 2);
	        end
        end
    end
        
    return oSeq;
end

