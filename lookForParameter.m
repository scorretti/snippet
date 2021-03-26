function value = lookForParameter (name, defval, varargin)

% lookForParameter            Look for a parameter in a list of arguments
% 
% Description:
% -----------
% This function looks for a given parameter in a list of arguments. The list of arguments must be
% in the format: 'arg-name', arg-value.
% If the argument is found, its value is returned. Otherwise, the provided default value is returned.
%
%
% Input:
% - name                      Name of the searched parameter
% - defval                    Default value
% ...                         List of arguments (i.e. varargin{:})
%
% Output:                     
% - value                     Value of the parameter
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
% 01-Mar-2021 - First version.

t = find(strcmpi(varargin(1:2:end), name));
if isempty(t)
  value = defval;
else
  value = varargin{2*t};
end

end


