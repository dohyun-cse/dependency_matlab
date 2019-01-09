function [H, G] = dispDep(G_or_directory)
% <SYNTAX>
%
% [H, G] = dispDep()
% [H, G] = dispDep(directory)
% [H, G] = dispDep(G)
%
% <DESCRIPTION>
%
% DISPDEP displays dependency plot from the table T and digraph G
% when a file is clicked, that file and its children and parents will be
% highlighted.
%
% [H, G] = dispDep() plot file hierarchy of current folder.
%
% [H, G] = dispDep(directory) plot file hierarchy of selected
% directory including its subfolders.
% 
% H = dispDep(G) plot file hierachy of given graph G. This is useful
% when G is already constructed by <genDependency>.
% 
% Input:
%       directory
%           Optional, string
%           folder name
%		G
%			Optional, digraph
%			dependency graph
%       
% 
% Output:
%		H
%			plot handle
%			graph
%       G
%           digraph
%           dependency graph
%
% See also, GENDEPENDENCY, HIGHLIGHTFUN
%
%% DATE         : August 04, 2018
%% VERSION      : 2.01
%% MATLAB ver.  : 9.5.0.944444 (R2018b)
%% AUTHOR       : Dohyun Kim
%% CONTACT      : kim92n@gmail.com

%======================================================== end of definition
%% PARSING

if nargin > 1
    error('Input arguments should be directory or digraph')
end
if nargin == 0 % if there is no input
    G_or_directory = pwd;
end
if ischar(G_or_directory) % if it is a path
    try
        directory = strrep(G_or_directory, filesep, '/');
        G = load([directory '/.dependency/dependency.mat']);
        G = G.G;
    catch
        G = genDep(G_or_directory);
    end
elseif isa(G_or_directory,'digraph') % if it is a dependency
    G = G_or_directory; % take it
    directory = [];
end

%% DISPLAY

fig = figure('windowstate','maximize');
ax = axes(fig);

% Highlight legend dummy plot
clist = get(0, 'defaultAxesColorOrder');
[dirlist, ~,idx] = unique(G.Nodes.Directory);
hold on;
for i = 1 : length(dirlist)
    plot(NaN,NaN,'color',clist(mod(i-1,size(clist,1))+1,:),'linestyle','none','marker','o','markerfacecolor',clist(mod(i-1,size(clist,1))+1,:), 'tag', num2str(i));
end

% plot graph
h = plot(G,'nodelabel',G.Nodes.Short_Name,'nodecolor',clist(1,:),'edgecolor',clist(1,:));
% highlight main scripts as pink
ismain = contains(G.Nodes.Row, 'main');
layout(h,'layered','Direction','left','sinks',find(ismain),'assignlayers','asap');

% current original color
orgNodeColor = h.NodeColor;
orgMarkerSize = h.MarkerSize;
orgEdgeColor = h.EdgeColor;
orgLineWidth = h.LineWidth;

for i = 1 : length(dirlist)
    if isempty(dirlist{i})
        dirlist{i} = 'root';
    end
    % highlight node by directory
    highlight(h, find(idx == i), 'nodecolor', clist(mod(i-1,size(clist,1))+1,:));
end
highlight(h,find(ismain),'nodecolor',[1,0.5,0.5],'markersize',12);
leg = legend(dirlist,'interpreter','none');

matlabversion = ver('MATLAB');
if matlabversion.Version >= 9.5
    h.Interpreter = 'none';
    h.NodeFontSize = 12;
end

title(ax, {directory, '..'});

% appearance
ax.Title.Interpreter = 'none';
axis(ax, 'tight');
set(ax,'XColor','none');
set(ax,'YColor','none');
set(ax,'color','none');
ax.Box = 'off';
ax.OuterPosition(1) = 0;
ax.OuterPosition(3) = 1;
ax.Position(1) = 0;
ax.Position(3) = 1;


% Set highlight function when it is pressed
adj = adjacency(G);
set(leg, 'ItemHitFcn', @(~,event) legHitFcn(event, h, idx, orgMarkerSize));
set(h, 'ButtonDownFcn', @(H, ~) clickcallback(h, adj, G, orgNodeColor, orgMarkerSize, orgEdgeColor, orgLineWidth));
set(ax, 'ButtonDownFcn', @(~, ~) dehighlightFun(h, orgNodeColor, orgMarkerSize, orgEdgeColor, orgLineWidth));
set(fig,'windowscrollwheelfcn',@(obj, evnt) wheelcallback(obj, evnt, ax));
button1 = uicontrol('Parent',fig,'Style','pushbutton','string','Search', 'visible','on');
button1.Callback = @(~,~) search_file(h, adj, G);

if nargout
    H = h;
end

end
%%
%========================================================== end of function

function clickcallback(h, adj, G, orgNodeColor, orgMarkerSize, orgEdgeColor, orgLineWidth)
persistent chk
if isempty(chk)
    chk = 1;
    pause(0.2); %Add a delay to distinguish single click from a double click
    if chk == 1
        highlightFun(h, adj, G, orgNodeColor, orgMarkerSize, orgEdgeColor, orgLineWidth);
        chk = [];
    end
else
    chk = [];
    % find selected node id
    p = get(h.Parent, 'CurrentPoint'); % mouse click position
    x = p(1,1); y = p(1,2);
    [~,nodeID] = min((h.XData-x).^2/diff(get(h.Parent,'XLim'))^2+(h.YData-y).^2/diff(get(h.Parent,'YLim'))^2); % min distance node
    edit(G.Nodes.Row{nodeID});
end
end
%%
%======================================================= end of subfunction


function highlightFun(h, adj, G, orgNodeColor, orgMarkerSize, orgEdgeColor, orgLineWidth)
    persistent  parentax subfig subax subh subG subid subnode
    % subid: node id of subgraph G relative to G
    % subnode : selected nodes to make subG
    if isempty(parentax) % if function is first excuted
        me = 1; % update current
        parentax{me} = h.Parent; % 
        subG = {}; subid = {[]}; subax = {}; subfig = {}; subnode = {[]};
    else
        me = [];
        for i = 1 : length(parentax)
            if eq(h.Parent,parentax{i})
                me = i;
            end
        end
        if isempty(me)
            me = length(parentax)+1;
            parentax{me} = h.Parent;
            subnode{me} = [];
        end
    end

    % if shift key is not pressed, remove highlight.
    modifier = get(h.Parent.Parent, 'CurrentModifier');
    if ~any(strcmp(modifier,'shift'))
        dehighlightFun(h, orgNodeColor, orgMarkerSize, orgEdgeColor, orgLineWidth);
    end
    
    % find selected node id
    p = get(h.Parent, 'CurrentPoint'); % mouse click position
    x = p(1,1); y = p(1,2);
    [~,nodeID] = min((h.XData-x).^2/diff(get(h.Parent,'XLim'))^2+(h.YData-y).^2/diff(get(h.Parent,'YLim'))^2); % min distance node

    % highlight selected node
    highlight(h,nodeID,'nodecolor','r','markersize',15) % highlight current node

    % get parents and children of current node
    parents = highlightParents(h, nodeID, adj);
    children = highlightChildren(h, nodeID, adj);
    
    if any(strcmp(modifier,'shift')) % if shift key is pressed
        h.Parent.Title.String{2} = [h.Parent.Title.String{2}, ',   ', strrep(G.Nodes(nodeID,:).Row{1}, h.Parent.Title.String{1}, '')];
        if isempty(subnode{me}) % if there is no subnode
            subnode{me} = 1; % set it to itself
            subid{me} = [];
        else % otherwise
            subnode{me} = [subnode{me}(:); length(subid{me}) + 1];
        end
        [subid{me}, ~, id] = unique([subid{me}(:);nodeID(:);parents(:);children(:)]); % append new node ID and its parents and children to subid
        subnode{me} = id(subnode{me});
    else
        h.Parent.Title.String{2} = strrep(G.Nodes(nodeID,:).Row{1}, h.Parent.Title.String{1}, '');
        % same but whithout append
        [subid{me},~,id] = unique([nodeID(:);parents(:);children(:)]);
        subid{me} = round(subid{me});
        subnode{me} = id(1);
    end

    if isempty(subG) % if there is no subgraph
        subG = {}; % initialize with empty cell
    end
    subG{me} = subgraph(G, subid{me}); % make subgraph

    if any(strcmp(modifier,'control')) % if control is pressed,
        % new figure
        if isempty(subfig) || length(subfig) < me || ~isvalid(subfig{me})
            subfig{me} = figure;
            screensize = get(0,'screensize');
            subfig{me}.Position(1:2) = screensize(3:4)/4;
            subfig{me}.Position(3:4) = screensize(3:4)/2;
        end
        
        % new axis
        if isempty(subax) || length(subax) < me || ~isvalid(subax{me})
            subax{me} = axes(subfig{me});
        end
        
        % draw subG
        subh{me} = plot(subax{me}, subG{me},'nodelabel',subG{me}.Nodes.Short_Name);
        layout(subh{me},'layered','Direction','left');
        matlabversion = ver('MATLAB');
        if matlabversion.Version >= 9.5
            subh{me}.Interpreter = 'none';
            subh{me}.NodeFontSize = 12;
        end
        
        % highlight selected node
        highlight(subh{me}, subnode{me}, 'nodecolor',[1,0.5,0.5],'markersize',15)

        % appearance of axis
        title(subax{me}, h.Parent.Title.String);
        subax{me}.Title.Interpreter = 'none';
        axis(subax{me}, 'tight');
        set(subax{me},'XColor','none');
        set(subax{me},'YColor','none');
        set(subax{me},'color','none');
        set(subax{me},'Box','off');
        subax{me}.OuterPosition(1) = 0;
        subax{me}.OuterPosition(3) = 1;
        subax{me}.Position(1) = 0;
        subax{me}.Position(3) = 1;
        
        % get current color
        orgNodeColor = subh{me}.NodeColor;
        orgMarkerSize = subh{me}.MarkerSize;
        orgEdgeColor = subh{me}.EdgeColor;
        orgLineWidth = subh{me}.LineWidth;
        
        % set highlight and dehighlight functions
        set(subh{me}, 'ButtonDownFcn', @(H, ~) clickcallback(subh{me}, subG{me}.adjacency, subG{me}, orgNodeColor, orgMarkerSize, orgEdgeColor, orgLineWidth));
        set(subax{me}, 'ButtonDownFcn', @(~, ~) dehighlightFun(subh{me}, orgNodeColor, orgMarkerSize, orgEdgeColor, orgLineWidth));
        set(subfig{me},'windowscrollwheelfcn',@(obj, evnt) wheelcallback(obj, evnt, subax{me}));
        
        % search button
        button1 = uicontrol('Parent',subfig{me},'Style','pushbutton','string','Search', 'visible','on');
        button1.Callback = @(~,~) search_file(subh{me}, subG{me}.adjacency, subG{me});
        
        % export button
        button2 = uicontrol('Parent',subfig{me},'Style','pushbutton','string','export project', 'visible','on');
        button2.Position(1) = 2*button1.Position(1) + button1.Position(3);
        button2.Position(3) = button1.Position(3)*2;
        button2.Callback = @(~,~) export_project(subG{me});
        
        % show persistent button
        button3 = uicontrol('Parent',subfig{me},'Style','pushbutton','string','show persistent', 'visible','on');
        button3.Position(1) = 2*button1.Position(1) + button1.Position(3) + button2.Position(3)*1.2;
        button3.Position(3) = button1.Position(3)*2;
        button3.Callback = @(~,~) show_persistent(subh{me}, subG{me});
        
    end
    
    drawnow;
end
%%
%======================================================= end of subfunction


function dehighlightFun(h, orgNodeColor, orgMarkerSize, orgEdgeColor, orgLineWidth)
    % set to original values
    h.NodeColor = orgNodeColor;
    h.MarkerSize = orgMarkerSize;
    h.EdgeColor = orgEdgeColor;
    h.LineWidth = orgLineWidth;
    h.Parent.Title.String{2} = '..';
end
%%
% ====================================================== end of subfunction


function newparents = highlightParents(h, nodeID, adj)

    parents = false(size(adj,1),1);
    parents(nodeID) = true;
    while true
        newparents = any(adj(parents,:),1); % nodes connected FROM current node
        oldnum = nnz(parents); % current the number of nodes
        parents = parents(:) | newparents(:); % update parents
        if nnz(parents) == oldnum % 
            break;
        end
    end
    adj(~parents,:) = false;
    [from, to] = find(adj);
    
    % highlight parent node and edge
    highlight(h,to,'nodecolor','m','markersize',12);
    highlight(h,from,to,'edgecolor','m','linewidth',2);
    
    newparents = unique(to);
end
%%
%======================================================= end of subfunction


function newchildren = highlightChildren(h, nodeID, adj)

    children = false(size(adj,1),1);
    children(nodeID) = true;
    while true
        newchildren = any(adj(:,children),2); % nodes connected FROM current node
        oldnum = nnz(children); % current the number of nodes
        children = children(:) | newchildren(:); % update parents
        if nnz(children) == oldnum % 
            break;
        end
    end
    adj(:,~children) = false;
    [from, to] = find(adj);
    
    % highlight parent node and edge
    highlight(h,from,'nodecolor','b','markersize',12);
    highlight(h,from,to,'edgecolor','b','linewidth',2);
    
    newchildren = unique(from);
end
%%
%======================================================= end of subfunction


function export_project(G)
    % dialog setting
    dlg_title = 'Export project';
    num_lines = 1;
    prompt = sprintf('Enter new project name.');
    % get new folder name
    newproj = char(inputdlg(prompt, dlg_title, num_lines));
    if isempty(newproj)
        warndlg('Invalid folder name.')
        return;
    end
    % make directory
    mkdir(newproj);
    
    % copy files
    for i = 1 : height(G.Nodes)
        try
            copyfile([G.Nodes.Row{i}], ['./' newproj '/' G.Nodes.Row{i}]);
        catch
            s = strfind(G.Nodes.Row{i}, '/');
            s = s(end);
            mkdir([newproj '/' G.Nodes.Row{i}(1:s)]);
            copyfile([G.Nodes.Row{i}], [newproj '/' G.Nodes.Row{i}]);
        end
    end
    msgbox('Project successfully exported.','Export project');
end
%%
%======================================================= end of subfunction


function show_persistent(h, G)
    
    ispersistent = false(length(G.Nodes.Row),1); % init
    for i = 1 : length(G.Nodes.Row) % for each file
        try
            fid = fopen(G.Nodes.Row{i}); % open file
            s = fscanf(fid,'%c',inf);
            if contains(s,'persistent') % if file contains persistent,
                ispersistent(i) = true; % mark
            end
            fclose(fid);
        catch
            error('Error occured while reading file <%s>',G.Nodes.Row{i});
        end
    end
    % highlight marked node as green
    highlight(h, find(ispersistent), 'nodecolor','g','markersize',10);
end
%%
%======================================================= end of subfunction


function search_file(h, adj, G)

    % dialog setting
    dlg_prompt = {'Enter File Name:'};
    dlg_title = 'Search';
    % get filename
    filename = inputdlg(dlg_prompt, dlg_title, 1);
    
    % find files which contains input filename
    hasnames = find(contains(G.Nodes.Short_Name, filename));
    switch numel(hasnames)
        case 0 % if there is no
            warndlg('There is no matching file. Try again'); % return warning
            return
            
        case 1 % if there is
            nodeID = hasnames; % select that one
            
        otherwise % if there are more than one file
            % select among them
            nodeID = hasnames(listdlg('PromptString', 'Select a file:', 'SelectionMode', 'single', 'ListString', G.Nodes.Short_Name(hasnames)));
    end
    
    % highlight searched file
    highlight(h,nodeID,'nodecolor','r','markersize',15) % highlight current node
    highlightParents(h, nodeID, adj);
    highlightChildren(h, nodeID, adj);
    
end
%%
%======================================================= end of subfunction


function wheelcallback(object, eventdata, ax)
modifier = object.CurrentModifier;
if length(modifier)>1 % if more than one key is pressed
    return; % do nothing
end

if isempty(modifier) % if nothing is pressed
    ax.XLim = ((ax.XLim - ax.CurrentPoint(1)) * 1.2^eventdata.VerticalScrollCount) + ax.CurrentPoint(1);
    ax.YLim = ((ax.YLim - ax.CurrentPoint(2)) * 1.5^eventdata.VerticalScrollCount) + ax.CurrentPoint(2);
    return;
end
switch modifier{1}
    case 'shift'
        ax.XLim = ax.XLim - eventdata.VerticalScrollCount * 0.3;
    case 'control'
        ax.YLim = ax.YLim + eventdata.VerticalScrollCount * 5;
end
end
%%
%======================================================= end of subfunction


function legHitFcn(event, h, idx,orgMarkerSize)
h.MarkerSize = orgMarkerSize;
highlight(h, find(idx == str2double(event.Peer.Tag)), 'markersize', 10);
end
%%
%============================================================== end of file
