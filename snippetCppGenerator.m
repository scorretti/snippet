classdef snippetCppGenerator < snippetGenerator
  
  % snippetCppGenerator         C++ code generator for Snippet
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
  % 22-Feb-2021 - First version.
  
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
      % coder                       instantiate a snippet coder with the C++ header
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
      % 22-Feb-2021 - first version.
      % 12-Mar-2021 - Modification: the synompsis of snippetCoder has changed.
      
      ver = snippet.getVersion();
      srcHeader = sprintf([ ...
        '// C++ MEX function generated automatically by snippet v %i.%i\n\n', ...
        '#include "mex.hpp"\n', ...
        '#include "mexAdapter.hpp"\n\n', ...
        ], ver.major, ver.minor);
      srcMain = sprintf([ ...
        '\n\nusing namespace matlab::data;\n', ...
        'using matlab::mex::ArgumentList;\n\n', ...
        'class MexFunction : public matlab::mex::Function {\n', ...
        'public:\n', ...
        '  void operator()(ArgumentList outputArg, ArgumentList inputArg) {\n', ...
        '    std::shared_ptr<matlab::engine::MATLABEngine> matlabPtr = getEngine();\n', ...
        '    ArrayFactory factory;       // factory to instantiate Matlab arrays\n', ...
        '    std::ostringstream stream;  // to display messages on the console\n', ...
        '']);
      srcEnd = sprintf([ ...
        '  }\n', ...
        '};\n']);
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
      % 15-Feb-2021 - first version.
      
      if Arg.isScalar()
        snippetCppGenerator.declareAsScalarInput(Arg, Cdr);
      else
        snippetCppGenerator.declareAsMatrixInput(Arg, Cdr);
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
      % 15-Feb-2021 - first version.
      % 24-Mar-2021 - Improvement:  scalar output are handled in a better way
      
       if Arg.isScalar()
        snippetCppGenerator.declareAsScalarOutput(Arg, Cdr);
      else
        snippetCppGenerator.declareAsMatrixOutput(Arg, Cdr);
      end
      
    end
  end
  
  % C++ specific auxiliary methods
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
      % 15-Feb-2021 - first version.
      
      [~, arrayType, cppType] = snippet.checkVariableType(Arg.type);
      Alias = {                       ...
        {'$POSITION', num2str(Arg.position)},  ...
        {'$TYPE', arrayType},           ...
        {'$CPPTYPE', cppType},        ...
        {'$NAME', Arg.name} };
      
      % It is assumed that variables to store the dimensions have already been declared as size_t
      for n = 1 : numel(Arg.dims)
        d = Arg.dims{n};
        if isnumeric(d)
          src = { ...
            '    if(inputArg[$POSITION].getDimensions()[$DIMENSION] != $SIZE) {', ...
            '      matlabPtr->feval(u"error", 0, ', ...
            '                       { factory.createScalar("Input #$POSITION (size: )") });', ...
            '    }'  ...
            };
          Cdr.code(src, { Alias{:}, {'$SIZE', int2str(d)}, {'$DIMENSION', int2str(n-1)} });
        elseif isa(d, 'snippetVariable')
          src = {'    $VARNAME = inputArg[$POSITION].getDimensions()[$DIMENSION];'};
          Cdr.code(src, { Alias{:}, {'$VARNAME', d.name}, {'$DIMENSION', int2str(n-1)} });
        else
          error('Unimplemented feature');
        end
      end
      
      switch Arg.mode
        case Arg.MODE_CONST
          src = {'    const TypedArray<$CPPTYPE> $NAME = inputArg[$POSITION];'};
        case Arg.MODE_MOVE
          src = {'    TypedArray<$CPPTYPE> $NAME = std::move(inputArg[$POSITION]);'};
        case Arg.MODE_COPY
          src = {'    TypedArray<$CPPTYPE> $NAME = inputArg[$POSITION];'};
        otherwise
          error('Unimplemented feature');
      end
      Cdr.code(src, Alias);
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
      
      [~, arrayType, cppType] = snippet.checkVariableType(Arg.type);
      Alias = {                       ...
        {'$POSITION', num2str(Arg.position)},  ...
        {'$TYPE', arrayType},           ...
        {'$CPPTYPE', cppType},        ...
        {'$NAME', Arg.name} };
      src_check = { ...
        '    if((inputArg[$POSITION].getType() != $TYPE)  ||  ' ,    ...
        '       inputArg[$POSITION].getNumberOfElements() != 1)', ...
        '    {' , ...
        '    matlabPtr->feval(u"error", 0, ', ...
        '                     { factory.createScalar("Input #$POSITION must be scalar $TYPE") });', ...
        '    }'  ...
        };
      Cdr.code(src_check, Alias);
      switch Arg.mode
        case Arg.MODE_CONST
          src_decl = {'    const $CPPTYPE $NAME = inputArg[$POSITION][0];'};
        case Arg.MODE_MOVE
          src_decl = {'    $CPPTYPE $NAME = inputArg[$POSITION][0];'};
        case Arg.MODE_COPY
          src_decl = {'    $CPPTYPE $NAME = inputArg[$POSITION][0];'};
        otherwise
          error('Internal error (wrong or unimplemented input mode)');
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
      
      if Arg.mode == Arg.MODE_NEW
        % The output argument is stored in a brand new variable, which has to be declared
        if isempty(Arg.dims)
          dims = '1';
        else
          dims = '';
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
            dims = [ dims, d ];
            if n < numel(Arg.dims) , dims = [ dims, ', ' ] ; end
          end
        end
        [~, arrayType, cppType] = snippet.checkVariableType(Arg.type);
        Alias = {                       ...
          {'$POSITION', num2str(Arg.position)},  ...
          {'$TYPE', arrayType},           ...
          {'$CPPTYPE', cppType},        ...
          {'$NAME', Arg.name},         ...
          {'$LIST_OF_DIMS', dims}};
        src = '    TypedArray<$CPPTYPE> $NAME = factory.createArray<$CPPTYPE>({ $LIST_OF_DIMS });';
        Cdr.code(src, Alias);
        
      elseif Arg.mode == Arg.MODE_INPUT
        % The output argument is an input argument (nothing to do)
      else
        error('Internal error');
      end
      
      Alias = {                         ...
        {'$POSITION', num2str(Arg.position)},  ...
        {'$NAME', Arg.name}};
      src = { ...
        '    if(outputArg.size() >= $POSITION+1) {', ...
        '      outputArg[$POSITION] = std::move($NAME);', ...
        '    }' ...
        };
      Cdr.afterCode(src, Alias);
    end
    function declareAsScalarOutput(Arg, Cdr)
      % declareAsScalarOutput       declare an output scalar argument
      %
      % Description:
      % -----------
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
      % 24-Mar-2021 - first version.
      
      % The output argument is stored in a brand new variable, which has to be declared
      [~, arrayType, cppType] = snippet.checkVariableType(Arg.type);
      Alias = {                       ...
        {'$POSITION', num2str(Arg.position)},  ...
        {'$TYPE', arrayType},           ...
        {'$CPPTYPE', cppType},        ...
        {'$NAME', Arg.name}};
      
      if Arg.mode == Arg.MODE_NEW
        src = '    $CPPTYPE $NAME;';
        Cdr.beforeCode(src, Alias);
        
      elseif Arg.mode == Arg.MODE_INPUT
        % The output argument is an input argument (nothing to do)
        
      else
        error('Internal error');
      end
      
      src = { ...
        '    if(outputArg.size() >= $POSITION+1) {', ...
        '      TypedArray<$CPPTYPE> __$NAME__ = factory.createArray<$CPPTYPE>({ 1 });', ...
        '      __$NAME__[0] = $NAME;', ...
        '      outputArg[$POSITION] = std::move(__$NAME__);', ...
        '    }' ...
        };
      Cdr.afterCode(src, Alias);
    end
  end
end

