classdef IOArgument < snippetVariable
  
  % IOArgument                  Input/Output argument of MEX functions
  %
  % Description:
  % -----------
  %
  % Input:
  % *
  %
  % Output:
  % *
  %
  % Notes:
  %
  % Example:
  %
  % See also:
  %
  % References:
  %
  % Validation:
  %
  % 15-Feb-2021 - First version.
  % 22-Feb-2021 - Revision:     most of methods are moved to the class snippetGenerator.
  % 15-Mar-2021 - Modification: property link, method setLink() added.
  
  % This file is part of Snippet.
  %
  % Snippet is free software: you can redistribute it and/or modify
  % it under the terms of the GNU Lesser General Public License as published by
  % the Free Software Foundation, either version 3 of the License, or
  % any later version (https://www.gnu.org/licenses/lgpl-3.0.txt).
  
  
  % --------------------------->| description of the function ---|------------------------------------------->| remarks
  
  
  properties
    dims = {};                  % Dimensions
    mode;                       % I/O mode (default = input MODE_MOVE)
    position;                   % Position in the list of I/O arguments
    link = [];                  % For output argument in MODE_INPUT only: linked input argument
  end
  
  % These modes define the way I/O arguments must be handled. This is briefly explained in Matlab
  % documentation (https://www.mathworks.com/help/matlab/matlab_external/copy-cpp-api-matlab-arrays.html):
  %  - "Array supports copy-on-write semantics. Copies of an Array object are unshared when a write
  %     operation is performed."
  %  - "C++ MATLAB (R) Data Arrays support move semantics. When you pass a variable using move, there is
  %     no copy of the variable."
  %  - "Avoid Unnecessary Data Copying: if you index into or use an iterator on an array for read-only
  %     purposes, then the best practice is to declare the array as const. Otherwise, the API functions
  %     might create a copy of the array in anticipation of a possible copy-on-write operation."
  properties(Constant)
    % Input arguments
    MODE_CONST = 1;             % The input argument is constant (will not be modified by the MEX routine)
    MODE_MOVE  = 2;             % The input argument will be modified, but it will not be reused)
    MODE_COPY  = 3;             % The input argument will be copied into a new variable
    
    % Output arguments
    MODE_NEW   = 1;             % A new variable must be declared for the output argument
    MODE_INPUT = 2;             % The output argument is also a (modified) input argument, hence no
    % new variable must be declared
  end
  
  methods
    function this = IOArgument(name, type, position, dims, mode)
      % Constructor
      %
      % Description:
      % -----------
      % An I/O argument is a variable with a set of dimensions, which can be used either as input or
      % output argument.
      % Dimensions are provided as a cell-array containing either variables (= instance of
      % snippetVariable) or strings.
      %
      %
      % Input:
      % - name                      Name of the I/O/ argument
      % - type                      Type
      % - position                  Position of the I/O argument
      % - dims                      Dimensions
      % - mode                      Input mode (default = MODE_MOVE)
      %
      % Output:
      % - this                      I/O argument
      %
      % Notes:
      %
      % Exemple:
      %
      % See also:
      %
      % References:
      %
      % Validation:
      %
      % 15-Feb-2021 - first version.
      % 20-Feb-2021 - Improvement:  symbolic constants are used for modes.
      
      this = this@snippetVariable(name, type);
      this.position = position;
      if nargin >= 4 , this.dims = dims ; end
      if nargin >= 5
        if ischar(mode)
          switch mode
            case ''
              % Keep the default value
            case 'const'
              this.mode = this.MODE_CONST;
            case 'new'
              this.mode = this.MODE_NEW;
            case 'move'
              this.mode = this.MODE_MOVE;
            case 'input'
              this.mode = this.MODE_INPUT;
            case 'copy'
              this.mode = this.MODE_COPY;
            otherwise
              error(sprintf('Unknown I/O mode (%s)', mode));
          end
          
        else
          this.mode = mode;
        end
      end
      
      % By default, the mode for input arguments is MODE_MOVE.
      % The mode is always explicitly provided in the case of output arguments
      if isempty(this.mode)
        this.mode = this.MODE_MOVE;
      end
    end
    function tf = isScalar(this)
      % isScalar                    true if an argument is scalar
      %
      % Description:
      % -----------
      % This method returns true if the I/O argument is scalar. That is, if the property dims is empty,
      % of if it stores the value 1.
      %
      %
      % Input:
      % - this                      I/O argument
      %
      % Output:
      % - tf                        true = the argument is scalar
      %
      % Notes:
      %
      % Exemple:
      %
      % See also:
      %
      % References:
      %
      % Validation:
      %
      % 15-Feb-2021 - first version.
      
      if numel(this.dims) == 0
        tf = true;
      elseif numel(this.dims) == 1
        d = this.dims{1};
        if isnumeric(d)  &&  d == 1
          tf = true;
        else
          tf = false;
        end
      else
        tf = false;
      end
    end
    function setLink(this, other)
      % setLink                     Create a link: output argument ---> input argument
      %
      % Description:
      % -----------
      % This method, for internal usage only, creates a link between this I/O argument and another
      % I/O argument with the same name. Normally, it is used to link an output argument with an
      % input argument with the same name. 
      % Notice that, at present time, this feature is allowed in C++ only.
      %
      % This method checks that <other> is an I/O argument, and that the names of both I/O arguments
      % (= this and other) are identical.
      %
      %
      % Input:
      % - this                      I/O argument
      % - other                     Another (input) I/O argument, with the same name
      %
      % Output:
      % *
      %
      % Notes:
      %
      % Exemple:
      %
      % See also:
      %
      % References:
      %
      % Validation:
      %
      % 15-Mar-2021 - first version.
      
      assert(isa(other, 'IOArgument'), 'internal error');
      assert(strcmp(this.name, other.name), 'internal error');
      this.link = other;
    end
  end
end
