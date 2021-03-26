classdef snippet < handle
  % snippet                     Snippet (= small portion of code)
  %
  % Description:
  % -----------
  % This class handle the generation of an "encapsulated" source C++ code, as well as the compilation
  % and execution of the snippet.
  % At present time, only C++ snippets are implemented, but C and Fortran are foreseen in future
  % versions.
  %
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
  % 13-Feb-2021 - First version.
  
  % This file is part of Snippet.
  %
  % Snippet is free software: you can redistribute it and/or modify
  % it under the terms of the GNU Lesser General Public License as published by
  % the Free Software Foundation, either version 3 of the License, or
  % any later version (https://www.gnu.org/licenses/lgpl-3.0.txt).
  
  % --------------------------->| description of the function ---|------------------------------------------->| remarks
  
  % For internal usage only (should go private)
  properties
    Variable;                   % Array of auxiliary variables
    InputArg;                   % Array of input arguments
    OutputArg;                  % Array of output arguments
    Coder;                      % Coder used to generate the source code of the MEX function
    fingerPrint = '';           % Finger-print of the source code
    tf_explicit = false;        % By default, the type of I/O arguments can be inferred automatically
    options;                    % Additional options passed to the mex compiler
  end
  
  properties
    sourceCode = {};            % Source code of the snippet
    language = 'c++';           % Programming language (default = C++). For future developments.
    Generator;                  % Class which generates the code for a specific language
  end
  
  properties(Constant)
    mexPath=snippet.getWorkingDirectory();      % Path where the source and executable codes are written
  end
  
  % Constructor and other methods
  methods
    function this = snippet(src, varargin)
      % Constructor
      %
      % Description:
      % -----------
      % The constructor takes as input arguments the source code of the snippet, and the options.
      % The source code can be provided directly as a cell-array of strings, or can be stored in a
      % source file. In this case, the programming language will be determined from the extension of
      % the file name.
      % It is not mandatory to provide options.
      %
      % Notice that the execution time of the constructor is usually negligible with respect of the
      % execution time of the snippet. That is, in principle you are not willing to write a snippet if
      % you can do the same with legacy Matlab code.
      %
      %
      % The life-cycle of a snippet is the following:
      %
      % Constructor:
      % -----------
      %  1.   Generation of the finger-print, basing on the source code only.
      %  2.   If a binary MEX-file with the same finger-print exists, exit (nothing to do).
      %  3.   Identify the I/O arguments (pre-compilation step) and eventually infere the type of input
      %       arguments from existing variables.
      %
      % Run:
      % ---
      %  4.   If no binary MEX-file with the same finger-print exists, generate the "encapsuled" code
      %       and compile it (compilation step).
      %  5.   Retrieve the input arguments, call the MEX-file and assign the value to the output
      %       argument.
      %
      % If no output argument is required, the snippet is immediatly run (= right after it has been
      % instantiated, before exiting from the constructor).
      %
      %
      %
      % Notice that there is a difference between input and output arguments:
      % - input arguments:  the type of input arguments may eventually be inferred from the variables
      %                     in caller workspace;
      % - output arguments: the type of output arguments cannot be inferred from existing variables. If
      %                     the type is not defined explicitly, and if it cannot be inferred from
      %                     input arguments, it is assumed that the default type is 'double'.
      %
      % Input:
      % - src                       Source code, or file name (.c, .cpp or .F)
      %
      % Optional inputs:
      % - 'language', lang          Specify the programming language (default = C++)
      % - 'compile', tf             If true, force recompiling the source code (default = false)
      % - 'options', {opts}         Options to pass directly to the command mex
      %
      %
      % Output:
      % - this                      Snippet
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
      % 22-Feb-2021 - Modification: property mexPath becomes constant.
      % 18-Mar-2021 - Improvement:  option 'compile' added.
      % 24-Mar-2021 - Improvement:  option 'options' added.
      
      % Handle optional arguments
      lang = lower(lookForParameter('language', 'c++', varargin{:}));
      
      % Initialize or import the source code
      if ischar(src)
        % The source code is written in a file. Identify the programming language from the extension
        filename = src;
        [~, ~, ext] = fileparts(filename);
        switch lower(ext)
          case {'.cpp', '.cxx'}
            this.language = 'c++';
          case '.c'
            this.language = 'c';
          case '.f'
            this.language = 'fortran';
          otherwise
            error('Unable to determine the programming language');
        end
        
        % Import the source code from a file
        if exist(filename, 'file')
          fid = fopen(filename, 'r');
          src = {};
          while ~feof(fid)
            src{end+1} = fgetl(fid);
          end
          fclose(fid);
        else
          error('file %s not found', filename);
        end
        
      elseif iscell(src)
        % The source code is provided as a cell-array of strings
        % By default, the programming language is C++
        assert(ismember(lang, {'c', 'c++', 'fortran'}));
        this.language = lang;
        
      else
        error('src must be either a file name (.c, .cpp or .f), or a cell-array containing the source code');
      end
      this.sourceCode = src;
      
      % Generate the finger-print of the source code. This allows to know if the code has been modified,
      % and hence has to be re-compiled.
      this.fingerPrint = this.generateFingerPrint(src);
      
      % Create a coder, according to the programming language
      switch this.language
        case 'c'
          this.Generator = snippetCGenerator();
        case 'fortran'
          this.Generator = snippetFortranGenerator();
        case 'c++'
          this.Generator = snippetCppGenerator();
        otherwise
          error('unknown programming language (%s)', this.language);
      end
      this.Coder = this.Generator.coder();
      this.reset();
      
      % Retrive the path of the function which invoked the constructor (this is very tricky...)
      [~, pth] = caller();      
      
      % Set the default options for the MEX compiler
      this.options = { ...
        '-O', ...               % Optimize the code
        '-R2018a', ...          % Use R2018a API
        ['-I' pwd()], ...       % Look for includes in the current directory
        ['-I' pth] ...          % Look for includes in directory where the caller function is stored
      };
      opts = lookForParameter('options', {}, varargin{:});
      this.options = [ this.options opts ];
      
      % If the snippet is not yet compiled, execute the pre-compilation step, which is required to
      % identify the type of input arguments from the existing variables in the caller's workspace
      if this.isNotCompiled()  ||  lookForParameter('compile', false, varargin{:})
        this.precompile();
        
        % Infere the type of undefined variables
        for n = 1 : numel(this.InputArg)
          Arg = this.InputArg(n);
          if isempty(Arg.type)
            if evalin('caller', ['exist(''' Arg.name ''', ''var'')'])
              Arg.type = evalin('caller', ['class(' Arg.name ');']);
            else
              error('Input argument %s does not exist (no variable with this name exists)', Arg.name);
            end
          end
        end
      end
      
      if lookForParameter('compile', false, varargin{:})
        this.compile();
      end
      
      % If no output arguments are required, compile and run the snippet
      if nargout == 0
        if this.isNotCompiled()
          this.compile();
        end
        
        % Invoke the gateway function from the caller's workspace
        [gateway, ~] = this.getFileName();
        evalin('caller', gateway);
      end
    end
    function explicit(this, tf)
      % explicit                    set the explicit option
      %
      % Description:
      % -----------
      % This method sets the tf_explicit flag. This flag defines the way I/O arguments with undefined
      % type will be handle during the pre-compilation step:
      %  - true : the type of all I/O arguments must be explicitly declared (an error is emitted)
      %  - false: the type of I/O arguments may eventually be inferred from the existing variables in
      %           the caller workspace, or from input arguments of the same name.
      %
      %
      %
      % Input:
      % - this                      Snippet
      % - tf                        True = the type of all I/O arguments must be explicitly declared
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
      % 22-Feb-2021 - first version.
      
      this.tf_explicit = tf;
    end
    function list(this)
      % list                        display the listing of the snippet
      %
      % Description:
      % -----------
      % This method displays the listing of the snippet in the console.
      %
      %
      % Input:
      % - this                      Snippet
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
      % 22-Feb-2021 - first version.
      
      disp(' ');
      for n = 1 : numel(this.sourceCode)
        disp(this.sourceCode{n});
      end
      disp(' ');
    end
    function edit(this)
      % edit                        Open the generated gateway and source MEX functions in the editor
      %
      % Description:
      % -----------
      % This method opens in Matlab editor the gateway function (.m) and the source MEX function.
      % This can be useful for debug purposes.
      %
      % Notice that in the snippet cannot be compiled (due to a bug), then in order to invoke this
      % method it is necessary to assign the snippet to a variable. For instance, consider the following
      % example, where a "dummy" anonymous snippet contains a bug:
      %
      % >> snippet({'for(i=0 ; i<10 ; ++i);'}, 'language', 'c');
      %
      % In this case the compilation fails because the variable i is undeclared. It is possible to
      % see the source code of the MEX function by modifying the code as:
      %
      % >> S = snippet({'for(i=0 ; i<10 ; ++i);'}, 'language', 'c');
      % >> S.run();
      %
      % Here the method run will fail, but it is then possible to invoke the method edit to see
      % source code. Notice that the same problem happens if you force the compilation:
      %
      % >> S = snippet({'for(i=0 ; i<10 ; ++i);'}, 'language', 'c', 'compile', true);
      % >> S.run();
      %
      % In this case, in order to see the source code it is mandatory to remove the 'compile', true
      % optional argument.
      %
      %
      % Input:
      % - this                      Snippet
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
      % 23-Mar-2021 - first version.
      
      [gateway, mexfile, ext] = this.getFileName();
      edit([this.mexPath filesep mexfile ext]);
      edit([this.mexPath filesep gateway]);
    end
    function reset(this)
      % reset                       clear all the variables, I/O arguments and reset the coder
      %
      % Description:
      % -----------
      % This method clears all the variables and I/O arguments and resets the coder, so that the
      % snippet can be recompiled.
      % This method is invoked by the constructor and by the method compile().
      %
      % Notice that neither the programming language, nor the finger-print are modified by this method.
      %
      %
      % Input:
      % - this                      Snippet
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
      % 21-Feb-2021 - first version.
      
      this.Variable = snippetVariable.empty();
      this.InputArg = IOArgument.empty();
      this.OutputArg = IOArgument.empty();
      this.Coder.reset();
    end
    function deleteBinary(this)
      % deleteBinary                delete all binary files and the gateway for the snippet
      %
      % Description:
      % -----------
      % This method deletes the gateway function, the source code and the binary of the snippet.
      % It can be usefull during development to force recompiling the snippet.
      %
      % *** THIS IS ANYWAY A DANGEROUS OPERATION ***
      %
      %
      % Input:
      % - this                      Snippet
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
      % 21-Feb-2021 - first version.
      
      [gateway, mexfile, ext] = this.getFileName();
      state = warning('off');
      delete([ this.mexPath filesep gateway '.m' ]);
      delete([ this.mexPath filesep mexfile ext ]);
      delete([ this.mexPath filesep mexfile '.' mexext ]);
      warning(state);
    end
    function run(this)
      % run                         run the snippet
      %
      % Description:
      % -----------
      % This method checks if the snippet is already compiled. If not, compile it on-the-fly.
      % Then, the snippet is executed in the caller workspace by calling the gateway function.
      %
      % Notice that it is mandatory to pass through the gateway function, in order to retrieve the
      % values of input arguments, and to assign the values to the output arguments.
      %
      %
      % Input:
      % - this                      Snippet
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
      % 12-Mar-2021 - Improvement:  minor modification
      % 13-Mar-2021 - Bug fixed:    the method failed if the snippet had to be recompiled, due to
      %                             evalin recursivity issue.
      
      % If required, compile the snippet. Unfortunately, due to the fact that evalin cannotbe used
      % recursively, it is necessary to cut and past the code required to infere the type of
      % undefined input arguments here :-(
      if this.isNotCompiled()
        % Pre-compile the snippet to identify input arguments
        this.precompile();
        
        % Infere the type of undefined input arguments
        for n = 1 : numel(this.InputArg)
          Arg = this.InputArg(n);
          if isempty(Arg.type)
            if evalin('caller', ['exist(''' Arg.name ''', ''var'')'])
              Arg.type = evalin('caller', ['class(' Arg.name ');']);
            else
              error('Input argument %s does not exist (no variable with this name exists)', Arg.name);
            end
          end
        end
        
        % Finally, compile the snippet
        this.compile();
      end
      
      % Invoke the gateway function from the caller's workspace
      gateway = this.getFileName();
      evalin('caller', gateway);
    end
    function tf = isNotCompiled(this)
      % isNotCompiled               check if the snippet must be compiled
      %
      % Description:
      % -----------
      % This method is the opposite of isCompiled().
      %
      %
      % Input:
      % - this                      Snippet
      %
      % Output:
      % - tf                        True = the snippet has to be compiled
      %
      % Notes:
      %
      % Exemple:
      %
      % See also: isCompiled()
      %
      % References:
      %
      % Validation:
      %
      % 22-Feb-2021 - first version.
      
      tf = ~ this.isCompiled();
    end
    function tf = isCompiled(this)
      % isCompiled                  check if the snippet is already compiled
      %
      % Description:
      % -----------
      % This method checks if the snippet is already compiled. The test is executed by checking if
      % the binary file corresponding to the MEX function exists. Notice that this algorithm is unable
      % to distinguish between different snippets with the same signature.
      %
      %
      % Input:
      % - this                      Snippet
      %
      % Output:
      % - tf                        True = the snippet is already compiled
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
      
      [~, mexfile, ext] = this.getFileName();
      binaryFileName = [this.mexPath filesep() mexfile '.' mexext()];
      if exist(binaryFileName, 'file') == 3
        tf = true;
      else
        tf = false;
      end
    end
  end
  
  methods
    function precompile(this)
      % precompile                  pre-compilation step
      %
      % Description:
      % -----------
      % The pre-compilation step looks for the I/O arguments and fills the properties InputArg and
      % OutputArg.
      %
      % The purpose of pre-compilation is to identify all the I/O arguments, and auxiliary
      % variables to store the sizes of I/O arguments. In particular, the pre-compilation step allows
      % to identify the input arguments the type of which is not explicitly declared in the
      % #pragma input. The type of these arguments can be inferred from the existing variables in
      % caller workspace.
      %
      % In practice, this method can be invoked only from the constructor of the class (= it should not
      % be invoked by the user). However, it may eventually be called from the user, with no
      % side-effect apart from a (small) increase of computational time.
      %
      % It is MANDATORY that the pre-compilation step is executed before the compilation step.
      %
      %
      % Input:
      % - this                      Snippet
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
      % 22-Feb-2021 - first version.
      % 11-Mar-2021 - Bug fixed:  in some cases compilation failed due to the fact that input arguments
      %                           had not been parsed. The bug has been fixed by checking if any
      %                           input arguments are declared. If not, the precompilation step is
      %                           executed, and if required the type of variables is inferred from
      %                           existing variables in caller's workspace.
      %                           Notice that it is mandatory to duplicate part of the code of the
      %                           constructor because the function evalin cannot recursively execute
      %                           a code in caller's caller's workspace.
      
      % Reset the state of the snipped, so that it can be compiled
      this.reset();
      
      % Generate the source code for the MEX file
      for p = 1 : numel(this.sourceCode)
        src = this.sourceCode{p};
        if this.handlePragma(src, true)
          % The line contains a specific #pragma directive (nothing else to do)
        else
          % Nothing to do
        end
      end
    end
    function compile(this, funName)
      % compile                     generate and compile the snippet
      %
      % Description:
      % -----------
      % This method generates the gateway function and the source code of the MEX function, and
      % compile it.
      %
      % Optionally, the name of the MEX file can be provided explicitly. In this case, this method
      % generates a "naked" MEX file (that is, with no gateway function) which can be distributed
      % indipendently from the source code.
      %
      % Notice that the pre-compilation step must already been executed, so that all of the
      % I/O arguments and their type are known.
      %
      %
      % Input:
      % - this                      Snippet
      % - funName                   Name of the MEX function (optional)
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
      % 12-Mar-2021 - Improvement:  #define and multi-line statements implemented
      % 19-Mar-2021 - Improvement:  a gateway is generated also for non-anonymous snippets
      % 25-Mar-2021 - Bug fixed:    an issue with the path of #include fixed (perhaps).
      
      % Check if the snippet needs to be pre-compiled
      if isempty(this.InputArg)
        this.precompile();
        
        % Infere the type of undefined variables
        for n = 1 : numel(this.InputArg)
          Arg = this.InputArg(n);
          if isempty(Arg.type)
            if evalin('caller', ['exist(''' Arg.name ''', ''var'')'])
              Arg.type = evalin('caller', ['class(' Arg.name ');']);
            else
              error('Input argument %s does not exist (no variable with this name exists)', Arg.name);
            end
          end
        end
      end
      
      % Resolve the type and the dimensions of output argument which are also input arguments
      for n = 1 : numel(this.OutputArg)
        Arg = this.OutputArg(n);
        if Arg.mode == IOArgument.MODE_INPUT
          [IArg, pos] = this.InputArg.findByName(Arg.name);
          assert(~isempty(pos), 'internal error');
          
          % Check that the declaration of input and output arguments are identical
          if isempty(Arg.type)
            Arg.type = IArg.type;
          else
            assert(strcmp(IArg.type, Arg.type), 'Conflicting type');
          end
          if isempty(Arg.dims)
            Arg.dims = IArg.dims;
          else
            assert(numel(Arg.dims) == numel(IArg.dims), 'Conflicting dimensions');
            for n = 1 : numel(Arg.dims)
              assert(isa(IArg.dims{n}, class(Arg.dims{n})), 'Conflicting dimensions');
              assert(isEqual(IArg.dims{n}, Arg.dims{n}), 'Conflicting dimensions');
            end
          end
          
          % Create a link: output argument ----> homonimous input argument
          Arg.setLink(IArg);
        end
      end
      
      % Reset the coder (it is assumed that all I/O arguments have been declared)
      this.Coder.reset();
      
      % Generate the source code for the MEX file
      tf_multiline = false;     % true = multi-line statement (in particular, #define)
      for p = 1 : numel(this.sourceCode)
        src = this.sourceCode{p};
        
        % Handle the special case of multi-line statements: if the flag tf_multiline is true, add the
        % line to the header section regardless of its contents, until the last non-empty character is
        % the multi-line continuation mark '\'.
        if tf_multiline
          this.Coder.header(src);
          src = strtrim(src);
          if src(end) ~= '\'
            tf_multiline = false;
          end
          continue
        end
        
        if this.handlePragma(src)
          % The line contains a specific #pragma directive (nothing else to do)
        elseif startsWith(src, '#include')
          % The line contains an #include
          % Try to find the full path of the file to be included
          t = find(src == '"');
          if ~isempty(t)  &&  numel(t) == 2
            includefilename = src(t(1)+1:t(2)-1);
            fullincludefilename = which(includefilename);
            if ~isempty(fullincludefilename)
              src = sprintf('#include "%s"', fullincludefilename);
            end
          end
          this.Coder.header(src);
        elseif startsWith(src, '#define')
          % The line contains an #define
          this.Coder.header(src);
          src = strtrim(src);
          if src(end) == '\'
            tf_multiline = true;
          end
        else
          % The line is an "ordinary" source code line
          this.Coder.code(['    ' src]);
        end
      end
      
      % Declare the auxiliary variables, used to store the sizes of I/O arguments
      this.Variable.declare(this.Coder);
      
      % Compile the code
      [gateway, mexfile, ext] = this.getFileName();
      if nargin < 2
        % A binary file and a gateway function are generated
        this.Coder.list([this.mexPath filesep mexfile ext]);
        mex([this.mexPath filesep mexfile ext], ...
          '-outdir', this.mexPath, this.options{:});
        
        % Generate the gateway function
        this.generateGateway();
        
      else
        % A "naked" binary function with the provided name is generated
        this.generateGateway(funName);
        this.Coder.list([funName '_' ext]);
        mex([funName '_' ext], this.options{:});
      end
    end
    function compileMex(this)
      % compileMex                  Compile the MEX file only
      %
      % Description:
      % -----------
      % This method compiles the MEX file corresponding to a snippet (the source file is NOT generated).
      % This and the method edit can be useful to make manual modifications to the MEX function, that
      % is:
      % 1.  generate the snippet,
      % 2.  edit the source code of the MEX function (method edit) and make some modifications directly 
      %     in the source code file,
      % 3.  compile it by using the method compileMex.
      %
      %
      % Input:
      % - this                      Snippet
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
      % 23-Mar-2021 - first version.
      
      [~, mexfile, ext] = this.getFileName();
      mex([this.mexPath filesep mexfile ext],  ...
        '-outdir', this.mexPath, this.options{:});
    end
    function generateGateway(this, fileName)
      % generateGateway             generate the gateway function of the snippet
      %
      % Description:
      % -----------
      % The gateway function is used to retrieve the values of input arguments, and to assign the
      % values to the output arguments. The gateway function MUST BE INVOKED FROM THE CALLER WORKSPACE.
      % This method generate the gateway function.
      %
      %
      % Input:
      % - this                      Snippet
      % - filename                  Name of the gateway function (optional)
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
      % 21-Feb-2021 - first version.
      % 11-Mar-2021 - Bug fixed:    the method failed when no output arguments was needed.
      % 18-Mar-2021 - Bug fixed:    The snippet produced a wrong result when any of the input arguments
      %                             was a row-vector. The reason is that row vectors are in fact
      %                             matrix of the form 1 x N. If the snippet requires as input a vector
      %                             (for instance x(N)), then the dimension N was not handled correctly.
      %                             The problem has been fixed by casting these vectors to column-
      %                             vectors before calling the MEX function.
      % 19-Mar-2021 - Improvement:  a gateway is generated also for non anonymous snippets.
      
      ver = this.getVersion();
      
      if nargin == 1
        % The snippet is anonymous
        [gateway, mexfile] = this.getFileName();
        fileName = [ this.mexPath filesep gateway '.m' ];
        fid = fopen(fileName, 'w');
        fprintf(fid, 'function %s()\n', gateway);
        
      else
        % The snippet is compiled to an ordinary MEX function
        gateway = fileName;
        mexfile = [ fileName '_' ];
        fileName = [ fileName '.m' ];
        fid = fopen(fileName, 'w');
        fprintf(fid, 'function ');
        
        if numel(this.OutputArg) > 0
          fprintf(fid, '[');
          for n = 1 : numel(this.OutputArg)
            Arg = this.OutputArg(n);
            fprintf(fid, '%s', Arg.name);
            if n < numel(this.OutputArg)
              fprintf(fid, ', ');
            end
          end
          fprintf(fid, '] = ');
        end
        
        fprintf(fid, '%s(', gateway);
        for n = 1 : numel(this.InputArg)
          Arg = this.InputArg(n);
          fprintf(fid, '%s', Arg.name);
          if n < numel(this.InputArg)
            fprintf(fid, ', ');
          end
        end
        fprintf(fid, ')\n');
        
        fprintf(fid, '%% %s\n%%\n', gateway);
        fprintf(fid, '%% Write the documentation of the function here\n%%\n');
        fprintf(fid, '%% Input:\n');
        for n = 1 : numel(this.InputArg)
          Arg = this.InputArg(n);
          fprintf(fid, '%% - %s : \n', Arg.name);
        end
        fprintf(fid, '%%\n%% Output:\n');
        for n = 1 : numel(this.OutputArg)
          Arg = this.OutputArg(n);
          fprintf(fid, '%% - %s : \n', Arg.name);
        end
        fprintf(fid, '%%\n');
      end
      fprintf(fid, '%% Generated automatically by snippet v %i.%i\n\n', ver.major, ver.minor);
      
      if nargin == 1
        % Generate the code to retrieve input arguments from the caller's workspace
        fprintf(fid, '%% Retrieve the input arguments from the caller workspace\n');
      end
      for n = 1 : numel(this.InputArg)
        Arg = this.InputArg(n);
        
        if nargin == 1
          fprintf(fid, '%s = evalin(''caller'', ''%s'');\n', Arg.name, Arg.name);
        end
        
        % This solves the issue with row-vectors
        if numel(Arg.dims) == 1
          fprintf(fid, '%s = %s(:);\n', Arg.name, Arg.name);
        end
        
        % this solves the issue with complex arguments
        switch Arg.type
          case 'double'
            fprintf(fid, '%s = double(%s);\n', Arg.name, Arg.name);
          case {'single', 'float'}
            fprintf(fid, '%s = single(%s);\n', Arg.name, Arg.name);
          case {'complex', 'std::complex<double>', 'complex<double>'}, ...
              fprintf(fid, '%s = complex(double(%s));\n', Arg.name, Arg.name);
          case {'std::complex<float>', 'complex<float>', 'std::complex<single>'}
            fprintf(fid, '%s = complex(single(%s));\n', Arg.name, Arg.name);
          case 'int8'
            fprintf(fid, '%s = int8(%s);\n', Arg.name, Arg.name);
          case 'uint8'
            fprintf(fid, '%s = uint8(%s);\n', Arg.name, Arg.name);
          case 'int16'
            fprintf(fid, '%s = int16(%s);\n', Arg.name, Arg.name);
          case 'uint16'
            fprintf(fid, '%s = uint16(%s);\n', Arg.name, Arg.name);
          case 'int32'
            fprintf(fid, '%s = int32(%s);\n', Arg.name, Arg.name);
          case 'uint32'
            fprintf(fid, '%s = uint32(%s);\n', Arg.name, Arg.name);
          case 'int64'
            fprintf(fid, '%s = int64(%s);\n', Arg.name, Arg.name);
          case 'uint64'
            fprintf(fid, '%s = uint64(%s);\n', Arg.name, Arg.name);
          otherwise
            error('internal error (unknown type)');
        end
      end
      
      % Generate the code to call the MEX function
      in = '';
      for n = 1 : numel(this.InputArg)
        Arg = this.InputArg(n);
        in = [ in Arg.name ];
        if n < numel(this.InputArg)
          in = [ in ', ' ];
        end
      end
      
      out = '';
      for n = 1 : numel(this.OutputArg)
        Arg = this.OutputArg(n);
        out = [ out Arg.name ];
        if n < numel(this.OutputArg)
          out = [ out ', ' ];
        end
      end
      fprintf(fid, '\n%% Call the compiled MEX function\n');
      
      if numel(this.OutputArg) > 0
        fprintf(fid, '[%s] = %s(%s);\n\n', out, mexfile, in);
      else
        fprintf(fid, '%s(%s);\n\n', mexfile, in);
      end
      
      if nargin == 1
        % Generate the code to assign the output arguments in the caller's workspace
        fprintf(fid, '%% Assign the output arguments in the caller workspace\n');
        for n = 1 : numel(this.OutputArg)
          Arg = this.OutputArg(n);
          fprintf(fid, 'assignin(''caller'', ''%s'', %s);\n', Arg.name, Arg.name);
        end
      end
      
      fprintf(fid, 'end\n');
      fclose(fid);
    end
    function [gateway, mexfile, ext] = getFileName(this)
      % getFileName                 return the file name of the gateway function and of the mex file
      %
      % Description:
      % -----------
      %
      % Input:
      % - this                      Snippet
      %
      % Output:
      % - gateway                   Name of the gateway (without the extension)
      % - mexfile                   Name of the MEX file (without the extension)
      % - ext                       Extension of the source MEX file
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
      
      switch this.language
        case 'c++'
          postfix = 'x';
          ext = '.cpp';
        case 'c'
          postfix = 'c';
          ext = '.c';
        case 'fortran'
          postfix = 'f';
          ext = '.F';
        otherwise
          error('Internal error (this should never happen)');
      end
      gateway = sprintf('sngtw_%s%s', this.fingerPrint, postfix);
      mexfile = sprintf('snmex_%s%s', this.fingerPrint, postfix);
    end
  end
  
  % Main methods
  methods
    function tf = handlePragma(this, src, tf_precompilation)
      % handlePragma                handle custom pragmas
      %
      % Description:
      % -----------
      % This method handles custom pragmas (= pragmas specifically defined for snippets). If a pragma
      % of a knonw type is found, the appropriate actions are taken and the value true is returnd.
      % Otherwise, it returnts the value false.
      %
      % Known pragmas are:
      % - #pragma [move|copy|const] input var[:type][(list-of-dimensions)], ...
      % - #pragma output var[:type][(list-of-dimensions)], ...
      % - #pragma explicit
      %
      %
      % This method has two possible behaviours:
      % - pre-compilation: I/O arguments are simply identified, and their type is allowed to be implicitly
      %                    defined from variables of caller's workspace (no code is generated)
      % - compilation    : I/O arguments must have already been identified, and their type must be
      %                    known. The code required to inport/export these arguments from/to the
      %                    caller's workspace is generated.
      %
      %
      % Input:
      % - this                      Snippet
      % - src                       Source code line
      % - tf_precompilation         True = pre-compilation mode (default = false)
      %
      % Output:
      % - tf                        True = a known #pragma has been found and processed
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
      
      if nargin < 3 , tf_precompilation = false ; end
      tf = false;
      src = strtrim(src);
      if startsWith(src, '#pragma ')
        [pragma, ~, ~, nxt] = sscanf(src(8:end), '%s', 1);
        src = src(8+nxt:end);
        
        % Check the special cases: #pragma [const | move | copy] input ...
        switch pragma
          case {'const', 'move', 'copy'}
            modifier = pragma;
            [pragma, ~, ~, nxt] = sscanf(src, '%s', 1);
            src = src(nxt:end);
            if strcmp(pragma, 'input')
              % Nothing to do
              
            elseif strcmp(pragma, 'output')
              warning('modifier %s applies only to input arguments', modifier);
              
            else
              % Modifiers const, move and copy applies only to input arguments
              % This rules out the options like #pragma move output, #pragma copy output, etc.
              tf = false;
              return
            end
            
          otherwise
            modifier = '';
        end
        
        % Depending on the #pragma directive, different actions are taken on
        switch pragma
          case 'input'
            % Declare one or more input arguments
            tf = true;
            decl = this.parseArgumentDeclaration(src);
            for n = 1 : numel(decl)
              if tf_precompilation
                % In the precompilation step, the arguments are simply declared
                this.addInputArgument(decl(n), modifier);
              else
                % In the true compilation step, it is assumed that arguments have already been parsed
                Arg = this.InputArg.findByName(decl(n).name);
                this.Generator.declareAsInput(Arg, this.Coder);
              end
            end
            
            
          case 'output'
            % Declare one or more output arguments
            tf = true;
            decl = this.parseArgumentDeclaration(src);
            for n = 1 : numel(decl)
              if tf_precompilation
                % In the precompilation step, the arguments are simply declared
                this.addOutputArgument(decl(n));
              else
                % In the true compilation step, it is assumed that arguments have already been parsed
                Arg = this.OutputArg.findByName(decl(n).name);
                % Arg.declareAsOutput(this.Coder);               % !!! HERE THE GENERATOR WILL BE USED !!!
                this.Generator.declareAsOutput(Arg, this.Coder);
              end
            end
            
            
          case 'explicit'
            % The type of all I/O arguments must be explicitly declared
            this.explicit(true);
            
          otherwise
            tf = false;
        end
      end
    end
    function Arg = addInputArgument(this, v, mode)
      % addInputArgument            add an input argument
      %
      % Description:
      % -----------
      % This method adds a new input argument. The input argument may be handled in different ways:
      % - mode = 'const':   the input argument is not going to be modified (any modification will
      %                     generate an error at compile time);
      % - mode = 'move':    the input argument is going to be modified, but the original value will
      %                     not be used any more;
      % - mode = 'copy'     the input argument will be copied and can be modified with no side-effect.
      %                     Notice that this will slow down the execution, and require additional memory
      %                     to store a copy of the argument.
      %
      % In principle, the type of the I/O arguments should be explicitly declared in the #pragma
      % directive. However, in case no type is explicitly defined, it is assumed that the type is
      % double.
      % *** This behaviour could change in future versions. ***
      %
      % Most of work is performed by the method addIOArgumentHelper().
      %
      %
      % Input:
      % - this                      Snippet
      % - v                         Declaration of the argument (returned by parseArgumentDeclaration()
      % - mode                      How the input must behandled (''=default, 'const', 'move' or 'copy')
      %
      % Output:
      % - Arg                       Input argument
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
      % 22-Feb-2021 - Modification: the behaviour of the method in case of undefined arguments has
      %                             been modified.
      
      % Handle the case of undefined argument type (DEPRECATED)
      % if isempty(v.type)
      %   v.type = 'double';
      % end
      
      % Handle the case of undefined argument type
      if this.tf_explicit  &&  isempty(v.type)
        error('Undefined type of input argument %s', v.name);
      end
      
      if nargin < 3 , mode = '' ; end
      assert(isempty(this.InputArg.findByName(v.name)), ...
        sprintf('Input argument %s is already defined', v.name));
      assert(isempty(this.OutputArg.findByName(v.name)), ...
        sprintf('Input argument %s is already defined as output argument', v.name));
      Arg = this.addIOArgumentHelper(v, numel(this.InputArg), mode);
      this.InputArg(end+1) = Arg;
    end
    function Arg = addOutputArgument(this, v)
      % addOutputArgument           add an output argument
      %
      % Description:
      % -----------
      % This method adds a new output argument. The output argument may be handled in different ways,
      % depending on whether an input argument with the same name exists or not:
      % - no intput argument with the same name exists (mode = 'new'): a new variable to store the
      %   output argument must be declared and initialized properly. If the type of the argument is
      %   not defined, it is assumed that type = 'double'.
      % - an input argument with the same name exists (mode = 'input'): no new variable has to be
      %   declared. The type of the output argument is "inherited" from the corresponding input
      %   argument
      %
      % Notice that, conversely to the case of the method addInputArgument(), the mode is determined
      % at run-time (the argument mode is missing).
      %
      % Notice that if a type is explicitly provided for the output argument, and if the output
      % argument exists also an input argument, then the types of input and output arguments must
      % match. Otherwise an error will be emitted.
      %
      % Most of work is performed by the method addIOArgumentHelper().
      %
      %
      % Input:
      % - this                      Snippet
      % - v                         Declaration of the argument (returned by parseArgumentDeclaration()
      %
      % Output:
      % - Arg                       Output argument
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
      % 15-Mar-2021 - Revision:       "magic number" 2 replaced by IOArgument.MODE_INPUT.
      
      % Handle the case of undefined argument type
      if this.tf_explicit  &&  isempty(v.type)
        error('Undefined type of output argument %s', v.name);
      end
      
      assert(isempty(this.OutputArg.findByName(v.name)), ...
        sprintf('Output argument %s already defined', v.name));
      vin = this.InputArg.findByName(v.name);
      if isempty(vin)
        % A new variable must be defined to store the output argument
        mode = 'new';
        if isempty(v.type)
          % In the case of output arguments, if the type of the argument is not defined, it is assumed
          % that it is double.
          warning('the type of output argument %s is assumed to be ''double''', v.name);
          v.type = 'double';
        end
        
      else
        % The output argument is an input argument, which is going to be modified
        % In this case, the type of the output argument is inherited from the input argument
        mode = 'input';
        if vin.mode ~= IOArgument.MODE_INPUT
          warning(sprintf('input argument %s should be explicitly declared with the modifier "move"', vin.name));
        end
        if isempty(v.type)
          v.type = vin.type;
        elseif ~isempty(vin.type)
          assert(v.type == vin.type, ...
            sprintf('Conflicting type between input and output argument (%s)', v.name));
        end
      end
      Arg = this.addIOArgumentHelper(v, numel(this.OutputArg), mode, true);
      this.OutputArg(end+1) = Arg;
    end
  end
  
  % Helper methods, for internal usage only
  methods(Access=private)
    function Arg = addIOArgumentHelper(this, v, position, mode, flag_output)
      % addIOArgumentHelper         Helper method for addInputArgument, addOutputArgument
      %
      % Description:
      % -----------
      % This method checks processes the expressions which defined the size of an I/O argument,
      % and returns an instance of IOArgument. More precisely, for each dimension there are three
      % options:
      %  1) an integer is provided,
      %  2) the name of a variable is provided,
      %  3) a valid expression is provided (for output arguments only)
      % Depending on the kind of value, each dimension will be stored either as an integer, an instance
      % of snippetVariable, or a string.
      %
      %
      % Input:
      % - this                      Snippet
      % - v                         Declaration of the argument (returned by parseArgumentDeclaration()
      % - position                  Position of the argument
      % - mode                      Input mode (optional)
      % - flag_output               Output mode (optional, default = false)
      %
      % Output:
      % - Arg                       I/O argument
      %
      % Notes:
      %
      % Exemple:
      %
      % See also: isVariableName()
      %
      % References:
      %
      % Validation:
      %
      % 15-Feb-2021 - first version.
      % 23-Mar-2021 - Modified:     A 5th argument (flag_output) has been added to fix a bug concerning
      %                             wrong (= undue) declaration of variables to store dimension of
      %                             output arguments.
      
      if nargin < 4 , mode = '' ; end
      if nargin < 5 , flag_output = false ; end
      dims = {};    % = list of dimensions (integer or snippet variable)
      for n = 1 : numel(v.dims)
        d = v.dims{n};
        [d_, st] = str2num(d);
        if st
          % If d is an integer, there is nothing else to do
          d = d_;
        elseif this.isVariableName(d)
          % If d is the name of a variable, convert it to an instance of snippetVariable and
          % add it to the list of known variables
          d = snippetVariable(d, 'size_t');
          if ~flag_output
            [this.Variable, ~] = this.Variable.insert(d);
          end
        else
          % Otherwise, it is assumed that d is a valid expression (nothing to do).
          % This option is allowed for output arguments only
        end
        dims{n} = d;
      end
      
      Arg = IOArgument(v.name, v.type, position, dims, mode);
    end
  end
  
  % Coder
  methods
    function [var, pos] = getVariable(this, name)
      % getVariable                 return a variable, given its name
      %
      % Description:
      % -----------
      % *** THIS METHOD IS NOT USED AND COULD BE REMOVED IN FUTURE VERSIONS ***
      %
      %
      % Input:
      % - this                      Snippet
      % - name                      Name of the variable
      %
      % Output:
      % - var                       Variable
      % - pos                       Index of the variable in the list
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
      
      [var, pos] = this.findByName(this.Variable, name);
    end
  end
  
  % Methods for compiling and generating the code
  methods(Static)
    function wd = getWorkingDirectory()
      % getWorkingDirectory         return the folder where MEX files will be written
      %
      % Description:
      % -----------
      % This method determines the working directory, where the generated files will be written and
      % executed, and add it to Matlab path in a non permanent way.
      %
      % Notice that this method can be modified for debug purposes.
      %
      %
      % Input:
      % *
      %
      % Output:
      % - wd                        Working directory
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
      % 13-Feb-2021 - first version.
      
      persistent mexPath
      
      % Initialize persistent data (this is executed only once)
      if isempty(mexPath)
        % Modify the following line to select the directory where compiled mex-files will be stored
        % True  : use $TEMP/$USER/.snippets
        % False : use $HOME/.snippets
        USE_TEMP_DIR = false;
        
        [user, userDir] = getuserdir();
        if isempty(user) , user = 'generic_user' ; end
        if USE_TEMP_DIR
          % Use the system temporary directory to store the compiled mex-files
          % (they could be eraser every time the PC is rebooted).
          % If the temporary directory is not defined, use the current directory (.)
          cpath = [ tempdir() user filesep() '.snippets' ];
          
        else
          % Use the home directory to store the compiled mex-files
          cpath = [ userDir '.snippets' ];
        end
        
        % In order to store the compiled mex-files in a particular directoy, just uncomment and modify
        % the following line (this could eventually be useful for debugging purpose)
        % cpath = <where to store snippets>;
        
        if isempty(cpath) , cpath = [ '.' filesep() '.snippets' ] ; end
        mexPath = cpath;
        if ~ exist(mexPath, 'dir')
          mkdir(mexPath);
        end
        addpath(mexPath);
      end
      
      wd = mexPath;
    end
    function fp = generateFingerPrint(src)
      % generateFingerPrint         Generate a finger-print of a cell-array of strings
      %
      % Description:                The purpose of the fingerprint is to provide an ID which is extremely likely
      %                             to be unique for each code. The source code (src) is shuffled and mixed, and
      %                             finally an hexadecimal representation is computed.
      %
      % Input:
      % - src                       Cell-array of strings (= source code)
      %
      % Output:
      % - fp                        Finger print (string)
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
      % 15-Jun-2018 - first version.
      % 12-Jun-2019 - Modification: due to limitations of Matlab, the fingerprint is trunked to 12 numbers
      
      % Concat all strings and allign to 16 bytes the length of the final string
      fp = strcat(src{:});
      nb = ceil(numel(fp) / 12);
      fp(nb*12) = '*';
      
      % Reshape the string so as to shuffle it, and writes the hexadecimal values of which remains
      fp = sum(reshape(fp, [nb 12]));
      fp = sprintf('%x', fp);
    end
    function ver = getVersion()
      % getVersion                  return the version of snippet
      %
      % Description:
      % -----------
      %
      % Input:
      % *
      %
      % Output:
      % - ver                       Structure containing the version (major, minor)
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
      % 21-Feb-2021 - first version.
      
      ver.major = 1;
      ver.minor = 0;
    end
    function info()
      % info                        display information about Snippet
      %
      % Description:
      % -----------
      % This method displays on the console the version of Snippet and the directory where snippets
      % are compiled.
      %
      %
      % Input:
      % *
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
      % 22-Feb-2021 - first version.
      % 24-Mar-2021 - Improvement:    C/C++ compilers are checked.
      
      ver = snippet.getVersion();
      fprintf('Snippet version                : %i.%i\n', ver.major, ver.minor);
      fprintf('Path where mex-files are stored: %s\n', snippet.mexPath);
      fprintf('---\n');
      fprintf('Snippet is distributed under the licence LGPL-3.0-or-later\n\n');
      
      % Test if the compiler toolchain is correctly installed and configured
      fprintf('Checking the compiler:\n');
      st_ = warning('off');
      try
        % Try to generate and compile a C snippet silently
        snippet({'int x = 0;'}, 'language', 'c', 'compile', true, 'options', {'-silent'});
        fprintf(' - MEX functions in C   can be compiled\n');
        
        % Try to generate and compile a C++ snippet silently
        snippet({'int x = 0;'}, 'language', 'c++', 'compile', true, 'options', {'-silent'});
        fprintf(' - MEX functions in C++ can be compiled\n');
        
      catch e
        warning(st_);
        fprintf('\n');
        warning('snippet:info:compilerDoesNotWork', [ ...
          '\n   The MEX compiler seems to be not installed or badly configured\n', ...);
          '   For more information about how to install and configure C/C++ compilers, see:\n', ...);
          '         <a href = "http://www.mathworks.com/help/matlab/ref/mex.html">http://www.mathworks.com/help/matlab/ref/mex.html</a>']);
        fprintf('\n*** Unable to run C/C++ snippets ***\n\n');
      end
      warning(st_);
      fprintf('\n');
    end
    function clear()
      % clear                       delete all snippets
      %
      % Description:
      % -----------
      % This method deletes all the snippets (= gateway and binaries) in the directory .snippets.
      %
      % *** THIS IS A DANGEROUS METHOD ***
      %
      %
      % Input:
      % *
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
      % 22-Feb-2021 - first version.
      
      delete([snippet.mexPath filesep() 'snmex_*.cpp']);
      delete([snippet.mexPath filesep() 'snmex_*.c']);
      delete([snippet.mexPath filesep() 'snmex_*.F']);
      delete([snippet.mexPath filesep() 'snmex_*.' mexext()]);
      delete([snippet.mexPath filesep() 'sngtw_*.m']);
    end
  end
  
  % Methods for parsing variables                              *** these methods should be protected ***
  methods(Static)
    function declaredArguments = parseArgumentDeclaration(declr)
      % parseArgumentDeclaration    Parse the declaration of one or more arguments
      %
      % Description:
      % -----------
      % This function takes as input a string containing the declaration of one or more variables, and
      % parse it. The function returns the description of each variable.
      % The synposis of declaration is:
      %
      %  <var_name>[:<type>][(dim1, dim2, ...)]
      %
      % The list of known types is hard-coded in the method checkVariableType.
      %
      % When more than one variable is declared, variables must be separated by comas (,). Spaces are
      % simply ignored.
      %
      %
      % Input:
      % - declr                     String describing a set of variables
      %
      % Output:
      % - declaredArguments(N)      Array of declared variables
      %
      % Notes:
      %
      % Example:
      %
      % See also: checkVariableType()
      %
      % References:
      %
      % Validation:
      %
      % 05-Jan-2021 - First version.
      % 06-Feb-2021 - Bug fixed:    function parsingErrorMsg was missing.
      % 22-Feb-2021 - Modification: renamed to parseArgumentDeclaration.
      % 18-Mar-2021 - Bug fixed:    this.parsingErrorMsg --> snippet.parsingErrorMsg
      
      emptyDeclaredVariable = struct('name', '', 'type', '', 'dims', {{}});
      declaredArguments = emptyDeclaredVariable;
      st = 0;
      for k = 1 : length(declr)
        % Skip blanks
        if declr(k) == ' ' , continue ; end
        
        switch st
          case 0   % = parsing the name of a variable
            if declr(k) == ','
              declaredArguments(end+1) = emptyDeclaredVariable;
              st = 0;
            elseif declr(k) == ':'
              st = 1;
            elseif declr(k) == '('
              dim = '' ; st = 2;
            else
              declaredArguments(end).name(end+1) = declr(k);
            end
            
          case 1   % = parsing the type of a variable
            if declr(k) == ','
              snippet.checkVariableType (declaredArguments(end).type);
              declaredArguments(end+1) = emptyDeclaredVariable;
              st = 0;
            elseif declr(k) == ':'
              % A variable cannot have two types
              error(snippet.parsingErrorMsg(declr, k));
            elseif declr(k) == '('
              snippet.checkVariableType (declaredArguments(end).type);
              dim = '' ; st = 2;
            else
              declaredArguments(end).type(end+1) = declr(k);
            end
            
          case 2   % = parsing the list of dimensions
            if declr(k) == ','
              declaredArguments(end).dims{end+1} = dim ; dim = '';
            elseif declr(k) == ')'
              declaredArguments(end).dims{end+1} = dim ; dim = '';
              st = 3;
            else
              dim(end+1) = declr(k);
            end
            
          case 3   % = waiting for a "," or end of the string
            if declr(k) == ','
              declaredArguments(end+1) = emptyDeclaredVariable;
              st = 0;
            else
              % Garbage found
              error(snippet.parsingErrorMsg(declr, k));
            end
            
          otherwise
            error('internal error (wrong parser state) -- this cannot happen!!!');
        end
      end
      
    end
    function msg = parsingErrorMsg(str, k)
      % parsingErrorMsg             Generate an error message, given a line which is being parsed
      %
      % Description:
      % -----------
      % This method is used internally by the method parseArgumentDeclaration().
      %
      %
      % Input:
      % - str                       Line to be displayed
      % - k                         Position where the error is found
      %
      % Output:
      % - msg                       Error message
      %
      % Notes:
      %
      % Exemple:
      % >> snippet.parsingErrorMsg('#pragma input j:complex', 17)
      %
      % ans =
      %
      % 'error while parsing the following line:
      %  #pragma input j:complex
      %                  ^
      % '
      %
      % See also:
      %
      % References:
      %
      % Validation:
      %
      % 13-Feb-2021 - first version.
      
      msg = sprintf([ ...
        'error while parsing the following line:\n' ...
        '%s\n'                                      ...
        '%s^\n'], str, blanks(k-1));
    end
    
    function [tf, varargout] = checkVariableType(vartype, lang)
      % checkVariableType           Check if the provided type is known
      %
      % Description:
      % -----------
      % This function checks if the provided type is known, and emits a warning message if
      % it is not known. Also, it returns the corresponding MEX and C++ type.
      %
      %
      % Input:
      % - vartype                   Type of variable
      % - lang='c++'                Programming language: C++ (default)
      %
      % Output:
      % - tf                        True = the type is known (otherwise, false).
      % - arrayType                 MATLAB ArrayType Value
      % - cppType                   C++ type
      %
      %
      % Input:
      % - vartype                   Type of variable
      % - lang='c'                  Programming language: C
      %
      % Output:
      % - tf                        True = the type is known (otherwise, false).
      % - classId                   Class ID
      % - cType                     C type
      % - mexType                   MEX type
      % - getfun                    Getter function
      %
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
      % 06-Feb-2021 - First version.
      % 15-Feb-2021 - Improvement:  MAX (= ArrayType) and C++ type is also returned.
      % 11-Mar-2021 - Improvement:  C type is also returned.
      % 12-Mar-2021 - Modification: the synopsis has completely changed so as to handle multiple
      %                             target languages.
      
      % By default, provide results for C++
      if nargin < 2 , lang = 'c++' ; end
      
      switch lang
        case 'c++'
          [tf, arrayType, cppType] = snippet.checkVariableTypeCpp(vartype);
          varargout{1} = arrayType;
          varargout{2} = cppType;
        case 'c'
          [tf, classId, cType, mexType, getfun] = snippet.checkVariableTypeC(vartype);
          varargout{1} = classId;
          varargout{2} = cType;
          varargout{3} = mexType;
          varargout{4} = getfun;
        case 'fortran'
          [tf, classId, fType] = snippet.checkVariableTypeFortran(vartype);
        otherwise
          error('Unimplemented programming language');
      end
    end
    function [tf, arrayType, cppType] = checkVariableTypeCpp(vartype)
      % checkVariableTypeCpp        Check if the provided type is known (C++ version)
      %
      % Description:
      % -----------
      % This function checks if the provided type is known, and emits a warning message if
      % it is not known. Also, it returns the corresponding array type [1] and native C++ type.
      %
      %
      % Input:
      % - vartype                   Type of variable
      %
      % Output:
      % - tf                        True = the type is known (otherwise, false).
      % - arrayType                 Type, as defined in matlab::data::ArrayType (C++)
      % - cppType                   Type (standard C++ type)
      %
      % Notes:
      %
      % Example:
      %
      % See also:
      %
      % References:
      % [1]   https://www.mathworks.com/help/matlab/apiref/matlab.data.arraytype.html
      %
      % Validation:
      %
      % 06-Feb-2021 - First version.
      % 15-Feb-2021 - Improvement:  MAX (= ArrayType) and C++ type is also returned.
      % 11-Mar-2021 - Improvement:  C type is also returned.
      % 13-Mar-2021 - Forked from checkVariableType.
      
      switch lower(vartype)
        case 'double'              % double precision floating point
          tf = true;
          arrayType = 'ArrayType::DOUBLE';
          cppType = 'double';
        case {'complex', 'std::complex<double>', 'complex<double>'}
          tf = true;
          arrayType = 'ArrayType::COMPLEX_DOUBLE';
          cppType = 'std::complex<double>';
        case {'single', 'float'}   % single precision floating point
          tf = true;
          arrayType = 'ArrayType::SINGLE';
          cppType = 'float';
        case {'std::complex<float>', 'complex<float>', 'complex<single>'}
          tf = true;
          arrayType = 'ArrayType::COMPLEX_SINGLE';
          cppType = 'std::complex<float>';
        case 'uint8'
          tf = true;
          arrayType = 'ArrayType::UINT8';
          cppType = 'uint8_t';
        case 'int8'
          tf = true;
          arrayType = 'ArrayType::INT8';
          cppType = 'int8_t';
        case 'uint16'
          tf = true;
          arrayType = 'ArrayType::UINT16';
          cppType = 'uint16_t';
        case 'int16'
          tf = true;
          arrayType = 'ArrayType::INT16';
          cppType = 'int16_t';
        case 'uint32'
          tf = true;
          arrayType = 'ArrayType::UINT32';
          cppType = 'uint32_t';
        case 'int32'
          tf = true;
          arrayType = 'ArrayType::INT32';
          cppType = 'int32_t';
        case 'uint64'
          tf = true;
          arrayType = 'ArrayType::UINT64';
          cppType = 'uint64_t';
        case 'int64'
          tf = true;
          arrayType = 'ArrayType::INT64';
          cppType = 'int64_t';
        case 'string'
          tf = true;
          arrayType = 'ArrayType::CHAR';
          cppType = 'char';
        case ''                    % undefined type (= the type is going to be resolved at run-time)
          tf = true;
          arrayType = '';
          cppType = '';
        otherwise
          tf = false;
          warning('Type %s unknown', vartype);
      end
    end
    function [tf, classId, cType, mexType, getfun] = checkVariableTypeC(vartype)
      % checkVariableTypeC          Check if the provided type is known (C version)
      %
      % Description:
      % -----------
      % This function checks if the provided type is known, and emits a warning message if
      % it is not known. Also, it returns the corresponding class ID [1] and native C type.
      %
      %
      % Input:
      % - vartype                   Type of variable
      %
      % Output:
      % - tf                        True = the type is known (otherwise, false).
      % - cppmexType                Type, as defined in matlab::data::ArrayType (C++)
      % - cppType                   Type (standard C++ type)
      % - cType                     Type (C type)
      % - mexType                   Equivalent (= typedef) types in MEX files
      % - getfun                    Getter function [2]
      %
      % Notes:
      %
      % Example:
      %
      % See also:
      %
      % References:
      % [1]   https://www.mathworks.com/help/matlab/apiref/mxcreatenumericmatrix.html
      % [2]   https://www.mathworks.com/help/matlab/cc-mx-matrix-library.html
      %
      % Validation:
      %
      % 06-Feb-2021 - First version.
      % 15-Feb-2021 - Improvement:  MAX (= ArrayType) and C++ type is also returned.
      % 11-Mar-2021 - Improvement:  C type is also returned.
      % 13-Mar-2021 - Forked from checkVariableType.
      
      switch lower(vartype)
        case 'double'              % double precision floating point
          tf = true;
          classId = 'mxDOUBLE_CLASS';
          cType = 'double';
          mexType = 'mxDouble';
          getfun = 'mxGetDoubles';
        case {'complex', 'std::complex<double>', 'complex<double>'}
          tf = true;
          classId = 'mxDOUBLE_CLASS';
          cType = 'double';
          mexType = 'mxComplexDouble';
          getfun = 'mxGetComplexDoubles';
        case {'single', 'float'}   % single precision floating point
          tf = true;
          classId = 'mxSINGLE_CLASS';
          cType = 'float';
          mexType = 'mxSingle';
          getfun = 'mxGetSingles';
        case {'std::complex<float>', 'complex<float>', 'complex<single>'}
          tf = true;
          classId = 'mxSINGLE_CLASS';
          cType = 'float';
          mexType = 'mxComplexSingle';
          getfun = 'mxGetComplexSingles';
        case 'uint8'
          tf = true;
          classId = 'mxUINT8_CLASS';
          cType = 'uint8_t';
          mexType = 'mxUint8';
          getfun = 'mxGetUint8s';
        case 'int8'
          tf = true;
          classId = 'mxINT8_CLASS';
          cType = 'int8_t';
          mexType = 'mxInt8';
          getfun = 'mxGetInt8s';
        case 'uint16'
          tf = true;
          classId = 'mxUINT16_CLASS';
          cType = 'uint16_t';
          mexType = 'mxUint16';
          getfun = 'mxGetUint16s';
        case 'int16'
          tf = true;
          classId = 'mxINT16_CLASS';
          cType = 'int16_t';
          mexType = 'mxInt16';
          getfun = 'mxGetInt16s';
        case 'uint32'
          tf = true;
          classId = 'mxUINT32_CLASS';
          cType = 'uint32_t';
          mexType = 'mxUint32';
          getfun = 'mxGetUint32s';
        case 'int32'
          tf = true;
          classId = 'mxINT32_CLASS';
          cType = 'int32_t';
          mexType = 'mxInt32';
          getfun = 'mxGetInt32s';
        case 'uint64'
          tf = true;
          classId = 'mxUINT64_CLASS';
          cType = 'uint64_t';
          mexType = 'mxUint64';
          getfun = 'mxGetUint64s';
        case 'int64'
          tf = true;
          classId = 'mxINT64_CLASS';
          cType = 'int64_t';
          cType = 'mxInt64';
          getfun = 'mxGetInt64s';
          
        case 'string'             % unimplemented feature (to do)
          error('to do');
          tf = true;
          classId = '';
          cType = 'char';
          mexType = 'char';
          
        case ''                    % undefined type (= the type is going to be resolved at run-time)
          
          tf = true;
          classId = '';
          cType   = '';
          mexType = '';
        otherwise
          tf = false;
          warning('Type %s unknown', vartype);
      end
    end
    
    function tf = isVariableName(str)
      % isVariableName              check if the given string is an allowed variable name
      %
      % Description:
      % -----------
      % This method checks if the provided string is an allowed variable name, that is:
      %  - it begins with a letter,
      %  - all of the characters after the first one are either a letter, or a digit, or underline
      % All of these conditions must be fulfilled. This is a possibly incomplete implementation which
      % cover most (but perhaps not all) of the allowed variable names.
      %
      %
      % Input:
      % - str                       Candidate to be a legal variable name
      %
      % Output:
      % - tf                        True = str is a legal variable name
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
      
      if isempty(str)
        tf = false;
      else
        str = upper(str);
        if 'A' <= str(1)  &&  str(1) <= 'Z'
          str = str(2:end);
          if isempty(str)
            tf = true;
          elseif all(('A' <= str  &  str <= 'Z')  |  ('0' <= str  &  str <= '9')  |  (str == '_'))
            tf = true;
          else
            tf = false;
          end
        else
          tf = false;
        end
      end
    end
  end
  
end


% = Third part functions ===================================================================================

function [user, userDir] = getuserdir()
% getuserdir                  Return the user name and user home directory
%
% Description:                This function is inspired from the original getuserdir() function by
%                             Sven Probst
%                             https://fr.mathworks.com/matlabcentral/fileexchange/15885-get-user-home-directory
%
% Input:
% *
%
% Output:
% - user                      User name
% - userDir                   User home directory
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
% 01-May-2019 - first version.

if ispc()
  user = getenv('USERNAME');
  userDir = getenv('USERPROFILE');
else
  user = getenv('USERNAME');
  userDir = getenv('HOME');
end
if ~isempty(userDir)  &&  userDir(end) ~= filesep()
  userDir(end+1) = filesep();
end
end
