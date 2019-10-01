function [varargout]=ww3mapmov(s,delay,varargin)
%WW3MAPMOV    Create map movie from a WaveWatch III hindcast GRiB1/2 file
%
%    Usage:    mov=ww3mapmov('file')
%              [mov1,...,movN]=ww3mapmov('file')
%              [...]=ww3mapmov('file',delay)
%              [...]=ww3mapmov('file',delay,rng)
%              [...]=ww3mapmov('file',delay,rng,cmap)
%              [...]=ww3mapmov('file',delay,rng,cmap,'mapopt1',mapval1,...)
%              [...]=ww3mapmov(s,...)
%
%    Description:
%     MOV=WW3MAPMOV('FILE') creates a Matlab movie of the WaveWatch III
%     handcast data contained in the GRiB file FILE.  MOV is the movie
%     struct that can then be converted to an AVI file using MOVIE2AVI.
%     There is a 1/3 second delay between each frame by default (see next
%     Usage form to adjust this).  If FILE is omitted or is empty then a
%     GUI is presented for GRiB file selection.  If no output is assigned
%     then WW3MAPMOV will "play" the data.
%
%     [MOV1,...,MOVN]=WW3MAPMOV('FILE') returns the movies for each
%     datatype in FILE (e.g., for wind data there is a movie for each
%     component).
%
%     [...]=WW3MAPMOV('FILE',DELAY) specifies the delay between the
%     mapping of each time step in seconds.  The default DELAY is 0.33s.
%
%     [...]=WW3MAPMOV('FILE',DELAY,RNG) sets the colormap limits of the
%     data. The default is dependent on the datatype: [0 15] for
%     significant wave heights and wind speed, [0 20] for wave periods,
%     [0 360] for wave & wind direction, & [-15 15] for u & v wind
%     components.
%
%     [...]=WW3MAPMOV('FILE',DELAY,RNG,CMAP) alters the colormap to CMAP.
%     The default is HSV for wave & wind direction and FIRE for everything
%     else.  The FIRE colormap is adjusted to best match the background
%     color.
%
%     [...]=WW3MAPMOV('FILE',DELAY,RNG,CMAP,'MMAP_OPT1',MMAP_VAL1,...)
%     passes additional options on to MMAP to alter the map.
%
%     [...]=WW3MAPMOV(S,...) creates a movie using the WaveWatch III data
%     contained in the structure S created by WW3STRUCT.
%
%    Notes:
%     - Requires that the njtbx toolbox is installed!
%     - Passing the 'parent' MMAP option requires as many axes as
%       datatypes.  This will only matter for wind data.
%
%    Examples:
%     % Calling WW3MAPMOV with no args lets you graphically choose a file:
%     mov=ww3mapmov;
%
%     % Save as an avi file:
%     movie2avi(mov,'filename.avi');
%
%     % Compress on linux (if you have mencoder available)
%     unixcompressavi('filename.avi');
%
%    See also: WW3MAP, WW3MOV, PLOTWW3, PLOTWW3TS, WW3STRUCT, WW3REC,
%              WW3CAT, MOVIE2AVI, UNIXCOMPRESSAVI, WW3UV2SA, WW3BAZ2AZ

%     Version History:
%        May   4, 2012 - initial version
%        Aug. 27, 2013 - use mmap image option
%        Jan. 15, 2014 - updated See also list
%        Feb.  5, 2014 - doc update, update for colormap input
%
%     Written by Garrett Euler (ggeuler at wustl dot edu)
%     Last Updated Feb.  5, 2014 at 00:40 GMT

% todo:

% check ww3 input
if(nargin==0) % gui selection of grib file
    % attempt reading in first record of file
    % - this does the gui & checks file is valid
    s=ww3struct([],1);
    if(~isscalar(s))
        error('seizmo:ww3mapmov:badWW3',...
            'WW3MAPMOV can only handle 1 file!');
    end
    read=true;
elseif(ischar(s)) % filename given
    % attempt reading in first record of file
    % - this does the gui & checks file is valid
    s=ww3struct(s,1);
    read=true;
elseif(isstruct(s))
    valid={'path' 'name' 'description' 'units' 'data' ...
        'lat' 'lon' 'time' 'latstep' 'lonstep' 'timestep'};
    if(~isscalar(s) || any(~ismember(valid,fieldnames(s))))
        error('seizmo:ww3mapmov:badWW3',...
            'S must be a scalar struct generated by WW3STRUCT!');
    end
    read=false;
else
    error('seizmo:ww3mapmov:badWW3',...
        'FILE must be a string!');
end

% get number of time steps
% - special file handling b/c we only read the 1st record
if(read)
    h=mDataset(fullfile(s.path,s.name));
    nrecs=numel(h{'time'}(:));
    close(h);
else
    nrecs=numel(s.time);
end

% check delay
if(nargin<2 || isempty(delay)); delay=0.33; end
if(~isreal(delay) || ~isscalar(delay) || delay<0)
    error('seizmo:ww3mapmov:badDelay',...
        'DELAY must be a positive scalar in seconds!');
end

% only make movie if output
makemovie=false;
if(nargout); makemovie=true; end

% make initial plot
ax=ww3map(ww3rec(s,1),varargin{:});
varargin=[varargin {'parent' ax}];
fh=get(ax,'parent');
if(iscell(fh)); fh=cell2mat(fh); end
for j=1:numel(fh)
    if(makemovie); varargout{j}=getframe(fh(j)); end
end

% now loop over records and plot them
for i=2:nrecs
    pause(delay);
    if(read); t=ww3struct(fullfile(s.path,s.name),i);
    else t=ww3rec(s,i);
    end
    if(any(~ishghandle(ax,'axes')))
        error('seizmo:ww3mapmov:userClose',...
            'Axes disappeared! Did someone turn off the lights?');
    end
    updateww3map(t,varargin{end});
    drawnow;
    for j=1:numel(fh)
        if(makemovie); varargout{j}(i)=getframe(fh(j)); end
    end
end

end

function [ax]=updateww3map(s,ax)
% time string
tstring=datestr(s.time,31);

% update each map
for i=1:numel(ax)
    % find previous
    pc=findobj(ax(i),'tag','m_pcolor');
    
    % slip in new data (note the doubling of the keyword end for pcolor)
    % - also do not color nans (land/ice)
    set(pc(1),'cdata',s.data{i}([1:end end],[1:end end]).');
    set(pc(1),'alphadata',...
        double(~isnan(s.data{i}([1:end end],[1:end end]).')));
    
    % update title
    set(get(ax(i),'Title'),'string',...
        {'NOAA WaveWatch III Hindcast' s.description{i} tstring});
end

end

