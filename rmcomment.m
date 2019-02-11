function txt = rmcomment(txt)
% rmcomment remove comment from text
%
% <SYNTAX>
%   txt = rmcomment(txt);
%   txt = rmcomment(filename);
%
% <DESCRIPTION>
% txt = rmcomment(txt) removes comment from txt(string).
% Here, "comment" means
%      1. Comment block surrounded by %{ %}
%      2. Inline comment starts with %
%      3. Any text after ...
%
% if txt is a filename, read given file and return its code after removing
% comment.
%
% <INPUT>
%     - txt (string)
%          code to remove comment or filename
%
% <OUTPUT>
%     - txt (string)
%          string with no comment
%
% See also

% Copyright 2019 Dohyun Kim / CC BY-NC

% Contact: kim92n@gmail.com
% Developed using MATLAB.ver 9.5 (R2018b) on Microsoft Windows 10 Enterprise

%%
if ~iscell(txt) && isfile(txt)
    fid = fopen(txt);
    txt = fread(fid, '*char').';
    fclose(fid);
end
    
charflag = false;

if ischar(txt)
    charflag = true;
    txt = {txt};
end

% delete section comment
% find %{ which has only blank between line starting and itself.
% then take all lines until
% find %} which has only blank between line starting and itself.
txt = cellfun(@(str) regexprep(str, '((^|\n)\s*%\{\s*\n([^\n]|\n)*?(\n\s*%\}))',''), txt, 'un', false);

% delete inline comments
% find % sign outside of the string
% how to find string?
% : surrounded by quotes (')
%     where the starting qute should not be next to
%     alphanumeric, underscore, ), ] nor }.
txt = cellfun(@(str) regexprep(str, '((^|\n)[^''%\n]*(((?<!(\w|\.|\]|\)|\}))''[^''\n]*'')[^%\n]*)*)%[^\n]*', '$1'), txt, 'un', false);
% delete everything after line continuations
% find ... blabla\n outside of the string
txt = cellfun(@(str) regexprep(str, '((^|\n)[^''\n]*(((?<!(\w|\.|\]|\)|\}))''[^''\n]*'')[^\n]*)*?)\.{3,}[^\n]*[\s]*', '$1'), txt, 'un', false);

% delete tailing white space
txt = cellfun(@(str) regexprep(str, '[^\S\n]+($|\n)', '$1'), txt, 'un', false);
% remove blank lines
txt = cellfun(@(str) regexprep(str, '\n+', '\n'), txt, 'un', false);
% if input was char
if charflag
    txt = txt{1};
end