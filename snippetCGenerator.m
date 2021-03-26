classdef snippetCGenerator < snippetGenerator
  
  % snippetCGenerator           C code generator for Snippet
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
  % 11-Mar-2021 - First version.
  
  % This file is part of Snippet.
  %
  % Snippet is free software: you can redistribute it and/or modify
  % it under the terms of the GNU Lesser General Public License as published by
  % the Free Software Foundation, either version 3 of the License, or
  % any later version (https://www.gnu.org/licenses/lgpl-3.0.txt).
  
  
  % --------------------------->| description of the function ---|------------------------------------------->| remarks
  
  % These methods must necessarily be implemented
  methods (Static)
    function Cdr = coder()
      % coder                       instantiate a snippet coder with the C header
      %
      % Description:
      % -----------
      %
      % Input:
      % *
      %
      % Output:
      % - Cdr                       Snippet coder
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
      % 11-Mar-2021 - first version.
      % 12-Mar-2021 - Modification: the synompsis of snippetCoder has changed.
      
      ver = snippet.getVersion();
      srcHeader = sprintf([ ...
        '// C MEX function generated automatically by snippet v %i.%i\n\n', ...
        '#include "mex.h"\n', ...
        '#include "matrix.h"\n', ...
        ], ver.major, ver.minor);
      srcEnd = sprintf([ ...
        '}\n']);
      srcMain = sprintf([ ...
        '\nvoid mexFunction( int nlhs, mxArray *plhs[],\n', ...
        '                  int nrhs, const mxArray *prhs[])\n', ...
        '{', ...
        ]);
      Cdr = snippetCoder(srcHeader, srcMain, srcEnd);
    end
    function declareAsInput(Arg, Cdr)
      % declareAsInput              declare an I/O argument as input argument
      %
      % Description:
      % -----------
      % Depending on the dimension and on the type of the I/O argument, this method delegates the job
      % to one of the methods declareAsMatrixInput() or declareAsScalarInput().
      %
      %
      % Input:
      % - Arg                       I/O argument
      % - Cdr                       Snippet coder
      %
      % Output:
      % *
      %
      % Notes:
      %
      % Exemple:
      %
      % See also: declareAsMatrixInput(), declareAsScalarInput()
      %
      % References:
      %
      % Validation:
      %
      % 11-Mar-2021 - first version.
      
      if Arg.isScalar()
        snippetCGenerator.declareAsScalarInput(Arg, Cdr);
      else
        snippetCGenerator.declareAsMatrixInput(Arg, Cdr);
      end
    end
    function declareAsOutput(Arg, Cdr)
      % declareAsOutput             declare an I/O argument as output argument
      %
      % Description:
      % -----------
      % Depending on the dimension and on the type of the I/O argument, this method delegates the job
      % to one of the method declareAsMatrixOutput().
      %
      %
      % Input:
      % - Arg                       I/O argument
      % - Cdr                       Snippet coder
      %
      % Output:
      % *
      %
      % Notes:
      %
      % Exemple:
      %
      % See also: declareAsMatrixOutput()
      %
      % References:
      %
      % Validation:
      %
      % 11-Mar-2021 - first version.
      
      snippetCGenerator.declareAsMatrixOutput(Arg, Cdr);
    end
  end
  
  % C specific auxiliary methods
  methods (Static)
    function declareAsMatrixInput(Arg, Cdr)
      % declareAsMatrixInput        declare an argument as a matrix input argument
      %
      % Description:
      % -----------
      % This method generates the code which handles a matrix input argument.
      % The code declares the required variable, and checks that the argument is of the right type.
      %
      % The generated code takes into account the modifier const, move or copy.
      %
      %
      % Input:
      % - Arg                       I/O argument
      % - Cdr                       Snippet coder
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
      % 12-Mar-2021 - first version.
      % 15-Mar-2021 - Refactored.
      
      [~, classId, cType, mexType, getfun] = snippet.checkVariableType(Arg.type, 'c');
      
      Alias = {                                 ...
        {'$POSITION', num2str(Arg.position)},   ...
        {'$TYPE', mexType},                     ...
        {'$CTYPE', cType},                      ...
        {'$NAME', Arg.name},                    ...
        {'$GETFUN', getfun} };

      % Implement here the check of argument type (to do)
      
      % It is assumed that variables to store the dimensions have already been declared as size_t
      switch numel(Arg.dims)
        case 1      % Particular case: the argument is a vector
          % Generate the code to get the size of the vector
          d = Arg.dims{1};
          if isnumeric(d)
            src = { ...
              '  if(mxGetM(prhs[$POSITION]) != $DIM) {', ...
              '    mexErrMsgIdAndTxt("MATLAB:snippet:rhs", "wrong input size ($POSITION)");', ...
              '  }'};
            Cdr.code(src, { Alias{:}, {'$DIM', int2str(d)} });
          else
            src = {'  $VARDIMNAME = mxGetM(prhs[$POSITION]);'};
            Cdr.code(src, { Alias{:}, {'$VARDIMNAME', d.name} });
          end
          
          % Generate the code to get the values
          src = { '  $TYPE *$NAME = $GETFUN(prhs[$POSITION]);' };
          Cdr.code(src, Alias);
            
        case 2      % Particular case: the argument is a matrix
          % Generate the code to get the size of the matrix
          fun = {'mxGetM', 'mxGetN'};
          for n = 1 : 2
            d = Arg.dims{n};
            if isnumeric(d)
              src = { ...
                '  if($FUN(prhs[$POSITION]) == $DIM) {', ...
                '    mexErrMsgIdAndTxt("MATLAB:snippet:rhs", "wrong input size ($POSITION)");', ...
                '  }'};
              Cdr.code(src, { Alias{:}, {'$DIM', int2str(d)}, {'$FUN', fun{n}} });
            else
              src = {'  $VARDIMNAME = $FUN(prhs[$POSITION]);'};
              Cdr.code(src, { Alias{:}, {'$VARDIMNAME', d.name}, {'$FUN', fun{n}} });
            end
          end
          
          % Generate the code to get the values
          d = Arg.dims{1}.name;
          if isnumeric(d), d = int2str(d) ; end
          src = {'  $TYPE (*$NAME)[$DIM] = ($TYPE (*)[$DIM]) $GETFUN(prhs[$POSITION]);'};
          Cdr.code(src, { Alias{:}, {'$DIM', d} });
          
          
        otherwise   % The argument is a multi-dimensional matrix
          % Generate the code to get the size of the multi-dimensional matrix
          src = { ...
            '  {', ...
            '  const mwSize *__pDims__ = mxGetDimensions(prhs[$POSITION]);' ...
            };
          Cdr.code(src, Alias);
          for n = 1 : numel(Arg.dims)
            d = Arg.dims{n};
            if isnumeric(d)
              src = { ...
                '  if(__pDims__[$N] != $DIM) {', ...
                '    mexErrMsgIdAndTxt("MATLAB:snippet:rhs", "wrong input size ($POSITION)");', ...
                '  }'};
              Cdr.code(src, { Alias{:}, {'$DIM', int2str(d)}, {'$N', int2str(n-1)} });
            else
              src = {'  $VARDIMNAME = __pDims__[$N];'};
              Cdr.code(src, { Alias{:}, {'$VARDIMNAME', d.name}, {'$N', int2str(n-1)} });
            end
          end
          Cdr.code('  }');
          
          % Generate the code to get the values
          sz = '';
          for n = 1 : numel(Arg.dims)-1
            d = Arg.dims{n};
            if isnumeric(d)
              sz = sprintf('[%i]%s', d, sz);
            else
              sz = sprintf('[%s]%s', d.name, sz);
            end
          end
          src = {'  $TYPE (*$NAME)$SIZE = ($TYPE (*)$SIZE) $GETFUN(prhs[$POSITION]);'};
          Cdr.code(src, { Alias{:}, {'$SIZE', sz} });
      end
    end
    function declareAsScalarInput(Arg, Cdr)
      % declareAsScalarInput        declare an input scalar argument
      %
      % Description:
      % -----------
      % This method generates the code which handles a scalar input argument.
      % The code declares the required variable, and checks that the argument is of the right type,
      % and that it is scalar.
      %
      % The generated code takes into account the modifier const. The modifier move is not taken into
      % account, because in the case of scalar arguments there is no performance gain.
      %
      %
      % Input:
      % - Arg                       I/O argument (must be scalar)
      % - Cdr                       Snippet coder
      %
      % Output:
      % *
      %
      % Notes:
      %   1)  The value of the parameter Arg.mode is not taken into account (at least, not in the
      %       present version).
      %
      % Exemple:
      %
      % See also:
      %
      % References:
      %
      % Validation:
      %
      % 11-Mar-2021 - first version.
      % 15-Mar-2021 - Refactored.
      
      [~, classId, cType, mexType, getfun] = snippet.checkVariableType(Arg.type, 'c');
      
      Alias = {                                 ...
        {'$POSITION', num2str(Arg.position)},   ...
        {'$TYPE', mexType},                     ...
        {'$CTYPE', cType},                      ...
        {'$NAME', Arg.name},                    ...
        {'$GETFUN', getfun} };
      src_check = { ...
        '    if(mxGetNumberOfElements(prhs[$POSITION]) != 1)', ...
        '    {' , ...
        '      mexErrMsgIdAndTxt("MATLAB:snippet:rhs", "Input $POSITION must be a scalar.");', ...
        '    }'  ...
        };
      Cdr.code(src_check, Alias);
      
      % Generate the code to catch the scalar and put it into a new variable
      switch mexType
        case 'mxDouble'
          src_decl = {'    $TYPE $NAME = mxGetScalar(prhs[$POSITION]);'};
        otherwise
          src_decl = {'    $TYPE $NAME = *$GETFUN(prhs[$POSITION]);'};
      end

      Cdr.code(src_decl, Alias);
    end
    function declareAsMatrixOutput(Arg, Cdr)
      % declareAsMatrixOutput       declare an output matrix argument
      %
      % Description:
      % -----------
      % This method generates the code which handles a matrix output argument. If the output is stored
      % in a new variable, this new variable is declared.
      %
      % The copy of the output argument to the variable outArg[n] is performed at the end of the code.
      % Hence, a single exit point is allowed (= it is forbidded to use the return instruction).
      %
      %
      % Input:
      % - Arg                       I/O argument
      % - Cdr                       Snippet coder
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
      % 20-Feb-2021 - first version.
      
      [~, classId, cType, mexType, getfun] = snippet.checkVariableType(Arg.type, 'c');
      Alias = {                                 ...
        {'$POSITION', num2str(Arg.position)},   ...
        {'$CLASSID', classId},                  ...
        {'$TYPE', mexType},                     ...
        {'$CTYPE', cType},                      ...
        {'$NAME', Arg.name},                    ...
        {'$GETFUN', getfun} };
      
      if Arg.mode == Arg.MODE_NEW
        % The output argument is stored in a brand new variable, which has to be declared
        if isempty(Arg.dims)  ||  ...
            (numel(Arg.dims) == 1  &&  isnumeric(Arg.dims)  &&  Arg.dims == 1)
          if strcmp(mexType, 'mxDouble')
            % Particular case: the output is scalar, double, real
            src_decl = '  mxDouble $NAME;';
            Cdr.code(src_decl, Alias);
            
            src = '  plhs[$POSITION] = mxCreateDoubleScalar($NAME);';
            Cdr.afterCode(src, Alias);
            
          else
            % Particular case: the output is scalar, other than double, real
            src_decl = '  $TYPE $NAME;';
            Cdr.code(src_decl, Alias);
            
            % Check if the output argument is complex or real
            if strcmp(mexType, 'mxComplexDouble')  ||  strcmp(mexType, 'mxComplexSingle')
              Alias{end+1} = {'$COMPLEX_FLAG', 'mxCOMPLEX'};
            else
              Alias{end+1} = {'$COMPLEX_FLAG', 'mxREAL'};
            end
            src_end = { ...
              '  plhs[$POSITION] = mxCreateNumericMatrix(1, 1, $CLASSID, $COMPLEX_FLAG);', ...
              '  *$GETFUN(plhs[$POSITION]) = $NAME;' ...
              };
            Cdr.afterCode(src_end, Alias);
          end
          
        else
          % General case
          dims = {};
          for n = 1 : numel(Arg.dims)
            d = Arg.dims{n};
            if isnumeric(d)
              d = int2str(d);
            elseif isa(d, 'snippetVariable')
              d = d.name;
            elseif ischar(d)
              % d is a valid C++ expression (nothing to do)
            else
              error('Internal error');
            end
            dims{end+1} = d;
          end
          if numel(dims) < 1 , dims{1} = '1' ; end
          
          % Check if the output argument is complex or real
          if strcmp(mexType, 'mxComplexDouble')  ||  strcmp(mexType, 'mxComplexSingle')
            Alias{end+1} = {'$COMPLEX_FLAG', 'mxCOMPLEX'};
          else
            Alias{end+1} = {'$COMPLEX_FLAG', 'mxREAL'};
          end

          if numel(dims) == 1
            % The output argument is a (column) vector
            Alias{end+1} = {'$M', dims{1}};
            src = { ...
              '  plhs[$POSITION] = mxCreateNumericMatrix($M, 1, $CLASSID, $COMPLEX_FLAG);', ...
              '  $TYPE *$NAME = ($TYPE *) $GETFUN(plhs[$POSITION]);' ...
              };
            Cdr.code(src, Alias);
            
          elseif numel(dims) == 2
            % The outout argument is a matrix
            Alias{end+1} = {'$M', dims{1}};
            Alias{end+1} = {'$N', dims{2}};
            src = { ...
              '  plhs[$POSITION] = mxCreateNumericMatrix($M, $N, $CLASSID, $COMPLEX_FLAG);', ...
              '  $TYPE (*$NAME)[$M] = ($TYPE (*)[$M]) $GETFUN(plhs[$POSITION]);' ...
              };
            Cdr.code(src, Alias);
            
          else
            % The output argument is a multi-dimensional matrix
            src = { ...
              '  {', ...
              '    mwSize __pDims__[$NBDIMS];' ...
              };
            for n = 1 : numel(dims)
              src{end+1} = sprintf('    __pDims__[%i] = %s;', n-1, dims{n});
            end
            Alias{end+1} = {'$NBDIMS', int2str(numel(dims))};
            src{end+1} = '    plhs[$POSITION] = mxCreateNumericArray($NBDIMS, __pDims__, $CLASSID, $COMPLEX_FLAG);';
            src{end+1} = '  }';
            
            listOfDims = '';
            for n = numel(dims)-1:-1:1
              listOfDims = [ listOfDims sprintf('[%s]', dims{n})];
            end
            Alias{end+1} = {'$LISTOFDIMS', listOfDims};
            src{end+1} = '  $TYPE (*$NAME)$LISTOFDIMS = ($TYPE (*)$LISTOFDIMS) $GETFUN(plhs[$POSITION]);'
            Cdr.code(src, Alias);
          end
        end
        
        
      elseif Arg.mode == Arg.MODE_INPUT
        % The output argument is an input argument
        error('It is forbidden to use a same argument for both input and output');
        
        % *** THIS DOES NOT WORK (= Matlab crashes) ***
        % assert(isa(Arg.link, 'IOArgument'), 'internal error (broken I/O link)');
        % src = 'plhs[$POSITION] = prhs[$INPUTPOSITION];';
        % Alias{end+1} = {'$INPUTPOSITION', int2str(Arg.link.position)};
        % Cdr.code(src, Alias);
        
      else
        error('Internal error');
      end
    end
  end
end

