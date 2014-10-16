rem = _value % interval;
rem = rem < 0 ? rem + interval : rem;
_value - rem;
