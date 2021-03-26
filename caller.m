function [fun, pth] = caller ()

% caller                      Return the name and the path of the caller function         
% 
% Description:
% -----------
% This function returns the name and the path of the caller function, that is the function which
% called the function from which caller() is invoked. It is more clear with an example:
% 
%  calls    function myfun()
%  +-----   anotherfun()
%  |        end                           
%  |
%  +---->   function anotherfun()
%           fprintf('caller = %s\n', caller());
%           end
%
% >> myfun
%
%    caller = myfun
%
% If the function has been invoked directly from Matlab console, caller() returns: fun = '', and 
% pth = pwd().
% 
%
% Input:
% *                           
%
% Output:                     
% - fun                       Name of the caller function, or empty
% - pth                       Directory where the caller function is stored, or current directory
%
% Notes:                      
%   1)  This function make use of the function dbstak, and hence it cannot be compiled.  
%
% Example:                    
%
% See also:                   
%
% References:                 
%
% Validation:                 
%
% 24-Mar-2021 - First version.
% 25-Mar-2021 - Modification: the function exhamines the call stack until it finds a non-empty
%                             state.

% Retrive the name of the function in the stack, skip the two first names 
for n = 2 : -1 : 0
  St = dbstack(n);
  if ~isempty(St) , break ; end
end

assert(~isempty(St), 'internal error');

if isempty(St)
  % The function has been invoked directly from Matlab command line (= base)
  fun = '';
  pth = pwd();
  
else
  % The function has been invoked by another function
  fun = St(1).name;
  pth = fileparts(which(fun));
end

end


