classdef snippetCoder < handle
  
  % snippetCoder
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
  % 20-Feb-2021 - Modification: the names of the sections have been modified: cpp*** --> src***.
  %                             The modification is motivated by the fact that indeed Matlab mex
  %                             command can compile .c, .cpp and .F source files with no modification
  %                             of the compiler options (= it identifies automatically the programming
  %                             language).
  
  % This file is part of Snippet.
  %
  % Snippet is free software: you can redistribute it and/or modify
  % it under the terms of the GNU Lesser General Public License as published by
  % the Free Software Foundation, either version 3 of the License, or
  % any later version (https://www.gnu.org/licenses/lgpl-3.0.txt).
  
  
  % --------------------------->| description of the function ---|------------------------------------------->| remarks
  
  properties
    srcHeader = {};             % Header to write in the very beginning of the program
    srcMain = {};               % Declaration of the main function
    srcBeforeCode = {};         % This goes BEFORE the user-defined algorithm
    srcCode = {};               % This is a carob-copy of the user-define algorithm
    srcAfterCode = {};          % This goes AFTER the user-defined algorithm
    srcEnd = {};                % This closes the program
  end
  
  properties (Access=private, Hidden=true)
    lineNumber = 1;             % Line number (used by list and listSection methods only)
  end
  
  methods
    function this = snippetCoder(srcHeader, srcMain, srcEnd)
      % Constructor
      %
      % Description:
      % -----------
      % This is the constructor of the class SnippetCoder. Two optional arguments must be provided:
      % - the header of the program,
      % - the end of the program.
      % By default, the code of an empty C++ MEX-function will be generated.
      %
      %
      % Input:
      % - srcHeader                 Header code
      % - srcMain                   Declaration of the main function
      % - srcEnd                    Ending code
      %
      % Output:
      % - this                      Snippet coder
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
      % 12-Mar-2021 - Bug fixed:    header and end section must be cell-array.
      % 12-Mar-2021 - Modification: section srcMain added.
      
      if nargin == 0
        % todo (remove ?)
        srcHeader = sprintf([ ...
          '// C++ MEX function generated automatically by snippet v 1.0\n\n', ...
          '#include "mex.hpp"\n', ...
          '#include "mexAdapter.hpp"\n\n', ...
          '']);
        srcMain = sprintf([ ...
          'using namespace matlab::data;\n', ...
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
      end
      this.srcHeader = { srcHeader };
      this.srcMain   = { srcMain };
      this.srcEnd    = { srcEnd };
    end
    function reset(this)
      % reset                       reset the coder
      %
      % Description:
      % -----------
      % This method clears all of the user-defined code, that is the sections cppBeforeCode, cppCode
      % and cppAfterCode.
      %
      %
      % Input:
      % - this                      Snippet coder
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
      
      this.srcBeforeCode = {};
      this.srcCode = {};
      this.srcAfterCode = {};
    end
    function buffer = header(this, src, alias)
      % header                      add some lines before the code section of the listing
      % 
      % Description:
      % -----------
      % This method adds one or more lines of source code to the header section of the program.
      % The new lines must be provided either as a string, or as a cell-array of strings.
      %
      % Each line can contain one or more "token", specified by the argument alias, which will be
      % replaced before generating the code.
      % Alias can be provided as a cell-array of the form:
      % { {token(1), replacing-string(1)} , {token(2), replacing-string(2)} , ... }
      %
      %
      % Input:
      % - this                      Snippet coder
      % - src                       Source code
      % - alias                     Aliases
      %
      % Output:
      % - buffer                    Line added to the header of the program
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
      
      if nargin < 3 , alias = {} ; end      % The argument alias can be empty, but it must exist
      buffer = this.preprocessing(src, alias);
      this.srcHeader{end+1} = buffer;
    end
    function buffer = beforeCode(this, src, alias)
      % beforeCode                  add some lines before the code section of the listing
      %
      % Description:
      % -----------
      % This method adds one or more lines of source code before the code section of the program.
      % The new lines must be provided either as a string, or as a cell-array of strings.
      %
      % Each line can contain one or more "token", specified by the argument alias, which will be
      % replaced before generating the code.
      % Alias can be provided as a cell-array of the form:
      % { {token(1), replacing-string(1)} , {token(2), replacing-string(2)} , ... }
      %
      %
      % Input:
      % - this                      Snippet coder
      % - src                       Source code
      % - alias                     Aliases
      %
      % Output:
      % - buffer                    Line added to the source code of the program
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
      
      if nargin < 3 , alias = {} ; end      % The argument alias can be empty, but it must exist
      buffer = this.preprocessing(src, alias);
      this.srcBeforeCode{end+1} = buffer;
    end
    function buffer = code(this, src, alias)
      % code                        add some lines to the code section of the listing
      %
      % Description:
      % -----------
      % This method adds one or more lines of source code to the code section of the program.
      % The new lines must be provided either as a string, or as a cell-array of strings.
      %
      % Each line can contain one or more "token", specified by the argument alias, which will be
      % replaced before generating the code.
      % Alias can be provided as a cell-array of the form:
      % { {token(1), replacing-string(1)} , {token(2), replacing-string(2)} , ... }
      %
      %
      % Input:
      % - this                      Snippet coder
      % - src                       Source code
      % - alias                     Aliases
      %
      % Output:
      % - buffer                    Line added to the source code of the program
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
      
      if nargin < 3 , alias = {} ; end      % The argument alias can be empty, but it must exist
      buffer = this.preprocessing(src, alias);
      this.srcCode{end+1} = buffer;
    end
    function buffer = afterCode(this, src, alias)
      % afterCode                   add some lines after the code section of the listing
      %
      % Description:
      % -----------
      % This method adds one or more lines of source code after the code section of the program.
      % The new lines must be provided either as a string, or as a cell-array of strings.
      %
      % Each line can contain one or more "token", specified by the argument alias, which will be
      % replaced before generating the code.
      % Alias can be provided as a cell-array of the form:
      % { {token(1), replacing-string(1)} , {token(2), replacing-string(2)} , ... }
      %
      %
      % Input:
      % - this                      Snippet coder
      % - src                       Source code
      % - alias                     Aliases
      %
      % Output:
      % - buffer                    Line added to the source code of the program
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
      
      if nargin < 3 , alias = {} ; end      % The argument alias can be empty, but it must exist
      buffer = this.preprocessing(src, alias);
      this.srcAfterCode{end+1} = buffer;
    end
    
    function list(this, fileName)
      % list                        Generate the listing of all of the sections
      %
      % Description:
      % -----------
      % This method writes the full program. The program is displayed in the console, unless a file
      % name is specified.
      %
      %
      % Input:
      % - this                      SnippetCoder
      % - fileName                  File name (optional)
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
      % 12-Mar-2021 - Modification: section srcMain added.
      % 13-Mar-2021 - Improvement:  line numbers can be printed.
      
      % Reset the line number counter
      this.lineNumber = 1;
      
      % By default, output te listing to the standard output
      if nargin < 2
        fid = 1;
        tf_displayLineNumbers = true;
      else
        if ischar(fileName)
          fid = fopen(fileName, 'w');
          tf_displayLineNumbers = false;
        elseif islogical(fileName)
          tf_displayLineNumbers = fileName;
        end
      end
      
      % Generate the listing of the header, the code and the end respectively
      this.listSection(this.srcHeader, fid, tf_displayLineNumbers);
      this.listSection(this.srcMain, fid, tf_displayLineNumbers);
      this.listSection(this.srcBeforeCode, fid, tf_displayLineNumbers);
      this.listSection(this.srcCode, fid, tf_displayLineNumbers);
      this.listSection(this.srcAfterCode, fid, tf_displayLineNumbers);
      this.listSection(this.srcEnd, fid, tf_displayLineNumbers);
      
      % If necessary, close the file
      if nargin >= 2
        fclose(fid);
      end
    end
    function listSection(this, section, fid, tf_displayLineNumbers)
      % listSection                 Generate the listing of a section of source code
      %
      % Description:
      % -----------
      %
      % Input:
      % - this                      SnippetCoder
      % - section                   Section of source code (cell-array of strings)
      % - fid                       File identifier
      % - tf_displayLineNumbers     True = display line numbers (default = false)
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
      % 13-Mar-2021 - Improvement:  this method is no more static, due to the possibility to print
      %                             line numbers.
      
      if nargin < 3 , fid = 1 ; end                       % By default, output to the standard output
      if nargin < 4 , tf_displayLineNumbers = false ; end % By default, don't print line numbers
      if ischar(section) , section = { section } ; end
      if tf_displayLineNumbers
        for n = 1 : numel(section)
          buffer = strrep(section{n}, newline(), sprintf('\n       '));
          fprintf(fid, '%4i : %s\n', this.lineNumber, buffer);
          this.lineNumber = this.lineNumber + 1;
        end
      else
        for n = 1 : numel(section)
          fprintf(fid, '%s\n', section{n});
        end
      end
    end
  end
  
  methods(Static)
    function buffer = preprocessing(src, alias)
      % preprocessing               replaces the alias with their actual value
      %
      % Description:
      % -----------
      % This method processes the alias. That is, each alias is replaced by its actual value.
      % This step is performed before the sections of the program are written to generate the full
      % program.
      %
      % The set of alias is provided as a cell-array. Each entry of the cell-array is an alias.
      % On its turn, each alias is provided as a cell-array on the form: { alias, value}. For instance:
      %    { '$CPPTYPE', 'double' }
      % During the pre-processing step, each occurrence of the string '$CPPTYPE' in the source code will
      % be replaced by the string 'dougle'.
      %
      %
      % Input:
      % - src                       Source code
      % - alias                     Set of alias
      %
      % Output:
      % - buffer                    Processed source code
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
      
      if ischar(src) , src = { src } ; end
      buffer = '';
      for n = 1 : numel(src)
        t = src{n};
        for a = 1 : numel(alias)
          t = strrep(t, alias{a}{1}, alias{a}{2});
        end
        buffer = [buffer sprintf('%s', t)];
        if n < numel(src) , buffer = [buffer newline] ; end
      end
    end
  end
end


