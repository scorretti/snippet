classdef (Abstract) snippetGenerator < handle
  
  % snippetGenerator            Ancestor of all code generators
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
  
  methods (Static,Abstract)
    Cdr = coder();              % Instantiate a snippet Coder with the appropriate header
    declareAsInput(Arg, Cdr);   % Declare a matrix as input argument
    declareAsOutput(Arg, Cdr);  % Declare a matrix as output argument
  end
end


