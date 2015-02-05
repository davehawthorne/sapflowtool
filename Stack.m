classdef Stack < handle
   properties
       stack
   end
   methods
       function o = Stack()
           o.stack = {};
       end
       
       function o = push(o, a)
           o.stack{end + 1} = a;
       end
       
       function a = pop(o)
           a = o.stack{end};
           o.stack = o.stack(1:end-1);
       end
       
       function a = peek(o)
           a = o.stack{end};
       end
       
       function a = empty(o)
           a = isempty(o.stack);
       end
       
       
   end
    
    
end