function GG = genDep(directory)
% genDep generates dependency graph
%
% <SYNTAX>
%   GG = genDep(directory);
%
% <DESCRIPTION>
% genDep(directory) generates dependency graph for given directory
% including its subfolder.
% When genDep is called without input, generates dependency graph
% for current folder.
% Resulting dependency graph will be stored in
% /.dependency/dependency.mat
% with variable name G which is digraph with filename table as nodes
%
% GG = genDep(_) returns dependency graph
%
% <INPUT>
%     - directory (string)
%          directory name to generate dependency graph. defualt: current folder
%
% <OUTPUT>
%     - GG (digraph)
%          dependency graph
%
% See also dispDep, rmcomment

% Copyright 2019 Dohyun Kim / CC BY-NC

% Contact: kim92n@gmail.com
% Developed using MATLAB.ver 9.5 (R2018b) on Microsoft Windows 10 Enterprise

%% PARSING

if nargin == 0
    directory = pwd;
end
directory = strrep(directory,filesep,'/');
files = dir(sprintf('%s/**/*.m',directory)); % get all matlab files

[dirnames{1:length(files)}] = files.folder;
[filenames{1:length(files)}] = files.name;

dirnames = strrep(dirnames, filesep, '/');
filenames = strrep(filenames, '.m', '');
if length(unique(filenames)) ~= length(filenames)
    warning('A repeated filename detected. The result may not be accurate.')
    [ufilenames,~,bak] = unique(filenames);
    warning(['Repeated names: ', ...
        sprintf('%s, ', ufilenames{accumarray(bak,1,[length(ufilenames),1])>1}), ...
        sprintf('\b\b')]);
end

if any(cellfun(@iskeyword,filenames))
    warning('A keyword name detected')

    warning(['Keyward names: ', ...
        sprintf('%s, ', filenames{cellfun(@iskeyword,filenames)}), ...
        sprintf('\b\b')]);
end

nrfiles = length(filenames);

clearvars files

%% GENERATE DEPENDENCY

fprintf('\nAnalyzing file ')

paths = cell(size(filenames));
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
    % remove function definitions to remove false self referencing
    filecontent = regexprep(filecontent, 'function [^\n]*', '');
    % find filename which does not have alphabet before and alphanumeric_ after.
    adj(:,n) = cellfun(@(filename) ~isempty(regexp(filecontent, ['\W', filename, '\W'], 'once')), filenames);

end
old_numbering_string_length = length(counting_string);
counting_string = sprintf('%i/%i\n', n, nrfiles);
fprintf(1, [repmat('\b',1,old_numbering_string_length), '%s'],  counting_string)

%% MAKE TABLE and GRAPH

T = table(filenames(:), cellfun(@(dirname) strrep(dirname, directory, ''), dirnames(:), 'un', false), 'RowNames', paths(:));
T.Properties.VariableNames = {'Short_Name', 'Directory'};
% T.Description
[T, idx] = sortrows(T, 'RowNames');

adj = adj(idx, idx);
G = digraph(adj, T);

%% SAVE and RETURN

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