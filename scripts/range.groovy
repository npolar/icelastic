rem = _value % interval;
rem = rem < 0 ? rem + interval : rem;
rint(_value - rem);
