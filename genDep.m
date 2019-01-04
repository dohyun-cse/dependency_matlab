function GG = genDep(directory)
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
%% RENAMED FROM : genDependency, August 06, 2018
%% DATE         : August 06, 2018
%% VERSION      : 1.00 
%% MATLAB ver.  : 9.4.0.813654 (R2018a)
%% AUTHOR       : Dohyun Kim
%% CONTACT      : kim92n@gmail.com

%=========================================================end of definition
%%
if ~nargin
    directory = pwd;
end
%% PART 1. LOAD DEPENDENCY

directory = strrep(directory, filesep, '/');
oldpwd = pwd;
cd(directory);
try
    G = load('./.dependency/G.mat','G'); % if exists
    G = G.G;
    fprintf('Dependency file exists. Update old files\n'); % found!
    T = G.Nodes; % get table
catch % if does not exist
    fprintf('Dependency file does not exist.\nCreate new one.\n');
    % create new table and graph
    T = table({},{},{},'RowNames', {});
    T.Properties.VariableNames = {'Short_Name', 'Date', 'Children'};
    G = digraph([],T);
end

%% PART 2. CHECK UPDATE AND DELETE

s = dir(sprintf('%s/**/*.m',strrep(pwd,filesep,'/'))); % get all matlab files

newfuns = {s.name}.'; newfuns = strrep(newfuns,'.m',''); % function name
newdates = cellfun(@(x) datetime(datevec(x)), {s.date}).'; % file creation dates
newpaths = {s.folder}.'; % full paths
newpaths = arrayfun(@(i) strrep(newpaths{i}, [pwd,filesep], ''), 1:length(newpaths),'UniformOutput',false);
newpaths = arrayfun(@(i) strrep(newpaths{i}, pwd, ''), 1:length(newpaths),'UniformOutput',false);
newpaths = arrayfun(@(i) strrep(newpaths{i}, filesep, '/'), 1:length(newpaths),'UniformOutput',false);
newpaths = arrayfun(@(i) [newpaths{i} '/' newfuns{i} '.m'], 1:length(newfuns),'UniformOutput',false); % include file name
for i = 1 : length(newpaths)
    if strcmp(newpaths{i}(1),'/')
        newpaths{i} = newpaths{i}(2:end);
    end
end

oldFiles = T.Row; % get old file names
isDeleted = true(length(oldFiles),1); % assume all file is deleted
isUpToDate = false(length(oldFiles),1); % assume all file is not up to date
for i = 1 : length(oldFiles) % for each file
    newid = find(strcmp(newpaths,oldFiles{i})); % check if old file still exists
    if ~isempty(newid) % if it exists,
        isDeleted(i) = false; % it is not deleted
        if T.Date(i) >= newdates(newid) % if it is not updated
            isUpToDate(i) = true; % data is up to date
            % delete from new files
            newfuns(newid) = [];
            newdates(newid) = [];
            newpaths(newid) = [];
%         else
%             T.Short_Name(i)
%             [T.Date(i) newdates(newid)]
%             pause
        end
    end
end

adj = G.adjacency; % get previous adjacency
hasDeletedChildren = any(adj(isDeleted,:),1); % find parents of deleted files
if any(isUpToDate(hasDeletedChildren)) % if parents is not updated, there must be a problem.
    % return error
    s = ['Parents of deleted files are not updated.' newline];
    s = [s, sprintf('%s\n',T.Row(~isUpToDate & hasDeletedChildren,:))];
    error(s);
end

%% PART 3. GET DEPENDENCY DATA FOR NEW DATA

% get dependency data
isNotMethod = ~contains(newpaths,'@');
isClass = false(size(isNotMethod));
for i = 1 : length(isNotMethod)
    if ~isNotMethod(i)
        st = strfind(newpaths{i},'@');
        st = st(end)+1;
        ed = strfind(newpaths{i},'/');
        ed = ed(ed>st);
        ed = ed(1)-1;
        if strcmp(newpaths{i}(st:ed),newfuns{i})
            isNotMethod(i) = true;
            isClass(i) = true;
        end
    end
end
newpaths = newpaths(isNotMethod);
newfuns = newfuns(isNotMethod);
newdates = newdates(isNotMethod);
isClass = isClass(isNotMethod);

fprintf('Generating Dependencies for %d files...', length(newfuns))
p = path;
addpath(genpath(pwd));
fList = arrayfun(...
    @(i) matlab.codetools.requiredFilesAndProducts(newpaths{i}, 'toponly'),  ...
    1:length(newpaths), 'uniformoutput',false);
fList = arrayfun(@(i) strrep(fList{i}, [pwd,filesep], ''), 1:length(fList),'UniformOutput',false);
fList = arrayfun(@(i) strrep(fList{i}, pwd, ''), 1:length(fList),'UniformOutput',false);
fList = arrayfun(@(i) strrep(fList{i}, filesep, '/'), 1:length(fList),'UniformOutput',false);
for i = 1 : length(fList)
    if isClass(i)
        newfuns{i} = ['@',newfuns{i}];
%         newpaths{i} = [newpaths{i}];
    end
end
rmpath(genpath(pwd));
addpath(p);
fprintf('\n');

%% PART 4. CONSTRUCT TABLE AND GRAPH

T = T(~isDeleted & isUpToDate,:); % remove deleted files from table.

fprintf('Creating adjacency matrix...');

% new table
% newpaths
T2 = table(newfuns(:), newdates(:), ...
    arrayfun(@(i) strjoin(fList{i}, ', '), 1:length(fList), 'UniformOutput',false).', ...
    'RowNames', newpaths);
T2.Properties.VariableNames = {'Short_Name', 'Date', 'Children'};

% prepare for update
oldLength = height(T); % store old the number of files
T = [T;T2]; % concatenate table
[T,idx] = sortrows(T,'RowNames'); % sort by function name and get index
adj = G.adjacency; % get old adjacency matrix
adj = adj(~isDeleted & isUpToDate, ~isDeleted & isUpToDate);
adj(height(T),height(T)) = 0; % adjust size for new graph

adj = adj(idx,idx); % reorder adjacency matrix for new table
[~,idx] = sort(idx);
idx = idx(oldLength + 1 : end); % remove old data

% Update adjacency matrix
for i = 1 : height(T2)
    for j = 1 : length(fList{i})
        adj(strcmp(T.Row,fList{i}{j}),idx(i)) = true;
    end
end
G = digraph(adj, T, 'OmitSelfLoops'); % renew graph
fprintf('\n');

if ~isfolder('./.dependency') % if folder does not exists
    mkdir ./.dependency % create folder
end
save ./.dependency/G.mat G % save graph

fprintf('Dependency generation is done.\n');
fprintf('File is saved in <%s/.dependency/G.mat>\n',strrep(pwd,filesep,'/'));
cd(oldpwd);
if nargout
    GG = G;
end
end