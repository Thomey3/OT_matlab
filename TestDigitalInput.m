% 创建数据采集会话
DAQ = daq('ni');

ch1 = addinput(DAQ,"dev1","port0/line0","Digital");

addlistener(ch1,'DataAvailable',@my_callback);
tt = 0;
while true
    [t,signal] = read(DAQ);
    if signal == 1
        tt = tt+1;
        if tt == 100
            disp(tt);
            tt = 0;
        end
    end
end