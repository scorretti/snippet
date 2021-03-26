classdef snippetVariable < handle
  
  % snippetVariable             Variable used in snippet
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
  
  % This file is part of Snippet.
  %
  % Snippet is free software: you can redistribute it and/or modify
  % it under the terms of the GNU Lesser General Public License as published by
  % the Free Software Foundation, either version 3 of the License, or
  % any later version (https://www.gnu.org/licenses/lgpl-3.0.txt).
  
  % --------------------------->| description of the function ---|------------------------------------------->| remarks
  
  properties
    name = '';
    type = '';
  end
  
  methods
    function this = snippetVariable(name, type)
      % Constructor
      %
      % Description:
      % -----------
      %
      % Input:
      % - name                      Name of the new variable
      % - type                      Type "   "   "     "
      %
      % Output:
      % - this                      Variable
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
      
      assert(nargin == 2  &&  ischar(name)  &&  ischar(type), ...
        'Synopsys: snippetVariable(name, type)');
      this.name = name;
      this.type = type;
    end
    function [var, pos] = findByName(this, name)
      % findByName                  Find a variable, given its name
      %
      % Description:
      % -----------
      %
      % Input:
      % - this                      Array of variables
      % - name                      Name of the searchd variable
      %
      % Output:
      % - var                       Variable
      % - pos                       Index of the variable
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
      
      pos = find(strcmp({ this.name }, name));
      if ~isempty(pos)
        var = this(pos);
      else
        var = [];
      end
    end
    function [this, pos] = insert(this, v)
      % insert                      Insert a new variable in an array of variables
      %
      % Description:
      % -----------
      % This method receives as input argument an array of variables (this) and a new variable (v).
      % First, the method looks for another variable with the same name. If such a variable is found
      % in the array, the method checks that the type of the new and existing variables are identical;
      % otherwise an error message is emitted. 
      % However, notice that if an ntyped variable with the same name already exists, this method will
      % modify the type of this variable according with the existing one (no new variable will be
      % added).
      % If no variable with the same name is found, add the new variable at the end of the array.
      % The position of the variable in the array is returned.
      %
      %
      % Input:
      % - this                      Array of variables
      % - v                         Variable
      %
      % Output:
      % - this                      Updated array of variables
      % - pos                       Index of the new variable in the array
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
      
      [v_, pos] = this.findByName(v.name);
      if isempty(pos)
        % The variable has not been found: insert the new variable into the list
        this(end+1) = v;
        pos = numel(this);
        
      else
        if isempty(v_.type)
          % The variable has been found, but it is untyped: modify its type
          v_.type = v.type;
        else
          % The variable has been found, and it is typed: check that types of the new and old
          % variable match.
          if ~strcmp(v_.type, v.type)
            error(sprintf('Conflicting type of variable %s (%s != %s)', v.name, v.type, v_.type));
          end
        end
      end
    end
    function code = declare(this, Cdr)
      % declare                     Generate the code to declare the lis of variables
      %
      % Description:
      % -----------
      %
      % Input:
      % - this                      Variable
      %
      % Output:
      % - code                      Automatically generated code
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
      % 15-Feb-2021 - first version.
      
      code = {};
      tab = '    ';
      listOfTypes = unique({this.type});
      for n = 1 : numel(listOfTypes)
        buffer = [tab listOfTypes{n} ' '];
        p = find(strcmp({this.type}, listOfTypes{n}));
        for k = 1 : numel(p)
          buffer = [ buffer, this(p(k)).name ];
          if k < numel(p) , buffer = [buffer, ', '] ; end
        end
        buffer(end+1) = ';';
        code{end+1} = buffer;
        
        % If a coder is provided, declare the variables before the main code
        if nargin >= 2
          Cdr.beforeCode(code);
        end
      end
    end
    function tf = isEqual(this, other)
      % isEqual                     Check that two variables are identical
      %
      % Description:
      % -----------
      % This method test if two variables are identical.
      % Notice that it is not possible to execute such a test by using the native == operator, 
      % because in fact == operator checks if two objects of the same class are the very same instance
      % (= the same instance of a single object). 
      % Conversely, this method checks if two distinct instances of the class snippetVariable are
      % identical.
      %
      %
      % Input:
      % - this                      Variable
      % - other                     Another variable
      %
      % Output:
      % - tf                        True = this and other have the same name and the same type
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
      
      tf = true;
      if ischar(this.name)  &&  (~ strcmp(this.name, other.name))
        tf = false ; return
      end
      if ~ strcmp(this.type, other.type)
        tf = false;
      end
    end
  end
  
end


