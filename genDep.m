function GG = genDep(directory, varargin)
% <SYNTAX>
%
% genDep
% genDep directory
% G = genDep(directory);
% G = genDep();
% 
% <DESCRIPTION>
% 
% GENDEP generates dependency graph for given directory including
% its subfolder.
% When GENDEP is called without input, generates dependency graph
% for current folder.
% 
% Input:
%		directory
%			Optional, string, default = pwd
%			target directory
% 
% Output:
%		GG
%			digraph
%			directed graph (callee -> caller).
%           GG.Nodes is a table of
%           <relative path>  Short_Name  Date  Children
%           where relative path does not contains its top level path.
% 
% See also, DISPDEPENDENCY
% 
%% DATE         : August 06, 2018
%% VERSION      : 2.01
%% MATLAB ver.  : 9.5.0.944444 (R2018b)
%% AUTHOR       : Dohyun Kim
%% CONTACT      : kim92n@gmail.com
%=========================================================end of definition
%%
if nargin == 0
    directory = pwd;
end
directory = strrep(directory,filesep,'/');
files = dir(sprintf('%s/**/*.m',directory)); % get all matlab files

[dirnames{1:length(files)}] = files.folder;
[filenames{1:length(files)}] = files.name;

dirnames = strrep(dirnames, filesep, '/');
filenames = strrep(filenames, '.m', '');

nrfiles = length(filenames);

clearvars files

%%

fprintf('\nAnalyzing file ')

paths = cell(size(filenames));
childrennames = cell(size(filenames));
adj = false(nrfiles, nrfiles);
counting_string = '';

for n = 1:nrfiles
    filename = [dirnames{n}, '/', filenames{n}, '.m'];
    paths{n} = strrep(filename, [directory, '/'], '');

    old_numbering_string_length = length(counting_string);
    counting_string = sprintf('%i/%i: %s', n, nrfiles, paths{n});
    fprintf(1, [repmat('\b', 1, old_numbering_string_length), '%s'],  counting_string)

    % read m-file
    fid = fopen(filename);
    filecontent = fread(fid, '*char').';
    fclose(fid);
    % remove comment
    filecontent = rmcomment(filecontent);
    % remove string
    filecontent = regexprep(filecontent, '''[^''\n]*''', '');
    % remove linecontinuation
    filecontent = regexprep(filecontent, '\.\.\.\s*', '');
    % remove function definition
    filecontent = regexprep(filecontent, 'function [^\n]*', '');
    % check whether filename appears or not
    adj(:,n) = cellfun(@(str) contains(filecontent, str), filenames);
    for m = find(adj(:,n).')
        othername = filenames{m};
        pos = strfind(filecontent, othername);
        flag = false;
        for pos1 = pos
            pos2 = pos1 + length(othername) - 1;
            if pos1 == 1
                candidate1 = '1';
            else
                candidate1 = filecontent(pos1 - 1 : pos2);
            end
            if pos2 == length(filecontent)
                candidate2 = '1';
            else
                candidate2 = filecontent(pos1 : pos2 + 1);
            end
            if ~(isvarname(candidate1) || isvarname(candidate2))
                flag = true;
                break;
            end
        end
        if ~flag
            adj(m,n) = true;
        end
    end
end
old_numbering_string_length = length(counting_string);
counting_string = sprintf('%i/%i\n', n, nrfiles);
fprintf(1, [repmat('\b',1,old_numbering_string_length), '%s'],  counting_string)

T = table(filenames(:), childrennames(:), 'RowNames', paths(:));
T.Properties.VariableNames = {'Short_Name', 'Children'};
[T, idx] = sortrows(T,'RowNames');

adj = adj(idx, idx);
G = digraph(adj, T);

if ~isfolder([directory, '/.dependency']) % if folder does not exists
    mkdir([directory, '/.dependency']) % create folder
end
save([directory, '/.dependency/dependency.mat'], 'G') % save graph

fprintf('Dependency generation is done.\n');
fprintf('File is saved in <%s/.dependency/dependency.mat>\n', directory);

if nargout
    GG = G;
end

end