classdef Stack < handle
    % A crude LIFO stack implementation.
    %
    % Supports the usual push() and pop().  Also peek() and empty().
    properties (Access = private)
        store % The 1 x N cell array used for the stack.
    end

    methods (Access = public)

        function o = Stack()
            % Constructs an empty stack.
            o.store = {};
        end

        function push(o, a)
            % Push to top
            o.store{end + 1} = a;
        end

        function a = pop(o)
            % Pop from top or die if empty.
            if isempty(o.store)
                error('Stack:pop', 'Tried popping from empty stack.');
            end
            a = o.store{end};
            o.store = o.store(1:end-1);
        end

        function a = peek(o)
            % Return from top of stack without popping.
            if isempty(o.store)
                error('Stack:peek', 'Tried peeking at empty stack.');
            end
            a = o.store{end};
        end

        function a = isEmpty(o)
            a = isempty(o.store);
        end


    end


end
