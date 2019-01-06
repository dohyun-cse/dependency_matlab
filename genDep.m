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
%% VERSION      : 2.00
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

    % Get content of file and remove special cases
    fid = fopen(filename);
    file_content = textscan(fid, '%s', 'Delimiter', '\n');
    file_content = file_content{1};
    fclose(fid);
    for line_num = 1 : length(file_content)
        file = file_content{line_num};
        
        % remove comment
        hascomment = sort([strfind(file, '%'), strfind(file, '...')]); % find possible comment starting points
        hasstring = strfind(file, ''''); % find string position
        [file, hasstring] = removecomment(file, hascomment, hasstring);
        
        % check occurence
        if ~isempty(file)
            [adj(:,n), linechildrennames] = iscalled(file, hasstring, n, adj(:,n), dirnames, filenames);
            childrennames{n} = [childrennames{n}, linechildrennames];
        end
    end
    if any(adj(:,n))
        childrennames{n} = childrennames{n}(3:end);
    end
end

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

%%

function [file, hasstring] = removecomment(file, hascomment, hasstring)

    if ~isempty(hascomment) % if there is candidate for comment,
        % check if it is comment
        if isempty(hasstring) % if there is no string
            file = file(1:hascomment(1) - 1); % it is comment.
        else % if there is comment
            for comment_position = 1:length(hascomment) % for each possible candidate,
                if ~mod(nnz(hasstring < hascomment(comment_position)),2)
                    % if there is even number of string before % or ...
                    % it is comment
                    file = file(1:hascomment(comment_position) - 1);
                    hasstring = hasstring(hasstring < hascomment(comment_position));
                    break;
                end
            end
        end
    end
end

%%

function [ischildren, childrens] = iscalled(file, hasstring, n, ischildren, dirnames, filenames)
    
    nrfiles = length(filenames);
    childrens = '';
    for other = 1:nrfiles
        if other == n || ischildren(other) % if itself or already searched,
            continue; % no need for further search
        end
        hasother = strfind(file, filenames{other}); % search for other file name
        if ~isempty(hasother) % if it contains other file name
            otherfile = filenames{other}; % get other file name
            % for each occurence, 
            for col = 1 : length(hasother)
                othercol = hasother(col);
                if mod(nnz(hasstring < othercol),2) % if it appeared in a string
                    continue % no need for further search
                end
                % candidate1 = current name including previous charactor
                % candidate2 = current name including next charactor
                % Those two must be not a varname.
                if othercol == 1 % if starting line
                    candidate1 = '1'; % give invalid name
                else % otherwise
                    % get current with previous
                    candidate1 = file(othercol-1 : othercol + length(otherfile) - 1);
                end
                if othercol + length(otherfile) > length(file) % if ending line
                    candidate2 = '1'; % 
                else
                    candidate2 = file(othercol : othercol + length(otherfile));
                end
                if ~isvarname(candidate1) && ~isvarname(candidate2)
                    ischildren(other) = true;
                    childrens = [childrens, ', ', dirnames{other}, '/', filenames{other}, '.m'];
                    break;
                end
            end
        end
    end
end