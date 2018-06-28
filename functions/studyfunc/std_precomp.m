% std_precomp() - Precompute measures (ERP, spectrum, ERSP, ITC) for channels or  
%                 components in a  study. If channels are interpolated before 
%                 computing the measures, the updated EEG datasets are also saved 
%                 to disk. Called by pop_precomp(). Follow with pop_plotstudy().
%                 See Example below.
% Usage:    
% >> [STUDY ALLEEG customRes] = std_precomp(STUDY, ALLEEG, chanorcomp, 'key', 'val', ...);
%
% Required inputs:
%   STUDY        - an EEGLAB STUDY set of loaded EEG structures
%   ALLEEG       - ALLEEG vector of one or more loaded EEG dataset structures
%   chanorcomp   - ['components'|'channels'| or channel cell array] The string 
%                  'components' forces the program to precompute all selected 
%                  measures for components. The string 'channels' forces the 
%                  program to compute all measures for all channels.
%                  A channel cell array containing channel labels will precompute
%                  the selected measures. Note that the name of the channel is
%                  not case-sensitive.
% Optional inputs:
%  'design'   - [integer] use specific study index design to compute measure.
%  'cell'     - [integer] compute measure only for a give data file.
%  'erp'      - ['on'|'off'] pre-compute ERPs for each dataset.
%  'spec'     - ['on'|'off'] pre-compute spectrum for each dataset.
%               Use 'specparams' to set spectrum parameters.
%  'ersp'     - ['on'|'off'] pre-compute ERSP for each dataset.
%               Use 'erspparams' to set time/frequency parameters.
%  'itc'      - ['on'|'off'] pre-compute ITC for each dataset.
%               Use 'erspparams' to set time/frequency parameters.
%  'scalp'    - ['on'|'off'] pre-compute scalp maps for components.
%  'allcomps' - ['on'|'off'] compute ERSP/ITC for all components ('off'
%               only use pre-selected components in the pop_study interface).
%  'erpparams'   - [cell array] Parameters for the std_erp function. See 
%                  std_erp for more information.
%  'specparams'  - [cell array] Parameters for the std_spec function. See 
%                  std_spec for more information.
%  'erspparams'  - [cell array] Optional arguments for the std_ersp function.
%  'erpimparams' - [cell array] Optional argument for std_erpimage. See
%                  std_erpimage for the list of arguments.
%  'recompute'   - ['on'|'off'] force recomputing ERP file even if it is 
%                  already on disk.
%  'rmicacomps'  - ['on'|'off'|'processica'] remove ICA components pre-selected in 
%                  each dataset (EEGLAB menu item, "Tools > Reject data using ICA 
%                  > Reject components by map). This option is ignored when 
%                  precomputing measures for ICA clusters. Default is 'off'.
%                  'processica' forces to process ICA components instead of
%                  removing them.
%  'rmclust'     - [integer array] remove selected ICA component clusters.
%                  For example, ICA component clusters containing
%                  artifacts. This option is ignored when precomputing
%                  measures for ICA clusters.
%  'customfunc'  - [function_handle] execute a specific function on each
%                  EEGLAB dataset of the selected STUDY design. The fist 
%                  argument to the function is an EEGLAB dataset. The
%                  function take the same list of argument as the std_erp
%                  function. Note that the data is only returned in the
%                  output of this function and is not saved in a data file.
%  'customparams' - [cell array] Parameters for the custom function above.
%  'customclusters' - [integer array] load only specific clusters. This is
%                    used with SIFT. chanorcomp 3rd input must be 'components'.
% 
% Obsolete input:
%  'savetrials'  - ['on'] save single-trials ERSP. Requires a lot of disk
%                  space (dataset space on disk times 10) but allow for refined
%                  single-trial statistics. This option is obsolete. As of
%                  EEGLAB 14, measures can only be saved in single trial
%                  mode.
%
% Outputs:
%   ALLEEG       - the input ALLEEG vector of EEG dataset structures, modified  
%                  by adding preprocessing data as pointers to Matlab files that 
%                  hold the pre-clustering component measures.
%   STUDY        - the input STUDY set with pre-clustering data added,
%                  for use by pop_clust()
%   customRes    - cell array of custom results (one cell for each pair of
%                  independent variables as defined in the STUDY design).
%                  If a custom file extension is specified, this variable
%                  is empty as the function assumes that the result is too
%                  large to hold in memory.
%
% Example:
%   >> [STUDY ALLEEG customRes] = std_precomp(STUDY, ALLEEG, { 'cz' 'oz' }, 'interp', ...
%               'on', 'erp', 'on', 'spec', 'on', 'ersp', 'on', 'erspparams', ...
%               { 'cycles' [ 3 0.5 ], 'alpha', 0.01, 'padratio' 1 });
%                          
%           % This prepares, channels 'cz' and 'oz' in the STUDY datasets.
%           % If a data channel is missing in one dataset, it will be
%           % interpolated (see eeg_interp()). The ERP, spectrum, ERSP, and 
%           % ITC for each dataset is then computed. 
%
% Example of custom call:
%   The function below computes the ERP of the EEG data for each channel and plots it.
%   >> [STUDY ALLEEG customres] = std_precomp(STUDY, ALLEEG, 'channels', 'customfunc', @(EEG,varargin)(mean(EEG.data,3)'));
%   >> std_plotcurve([1:size(customres{1},1)], customres, 'chanlocs', eeg_mergelocs(ALLEEG.chanlocs)); % plot data
%
%   The function below uses a data file to store the information then read
%   the data and eventyally plot it
%   >> [STUDY ALLEEG customres] = std_precomp(STUDY, ALLEEG, 'channels', 'customfunc', @(EEG,varargin)(mean(EEG.data,3)), 'customfileext', 'tmperp');
%   >> erpdata = std_readcustom(STUDY, ALLEEG, 'tmperp');
%   >> std_plotcurve([1:size(erpdata{1})], erpdata, 'chanlocs', eeg_mergelocs(ALLEEG.chanlocs)); % plot data
%
% Authors: Arnaud Delorme, SCCN, INC, UCSD, 2006-

% Copyright (C) Arnaud Delorme, SCCN, INC, UCSD, 2006, arno@sccn.ucsd.edu
%
% This program is free software; you can redistribute it and/or modify
% it under the terms of the GNU General Public License as published by
% the Free Software Foundation; either version 2 of the License, or
% (at your option) any later version.
%
% This program is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
% GNU General Public License for more details.
%
% You should have received a copy of the GNU General Public License
% along with this program; if not, write to the Free Software
% Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

function [ STUDY, ALLEEG customRes ] = std_precomp(STUDY, ALLEEG, chanlist, varargin)
    
    if nargin < 2
        help std_precomp;
        return;
    end
    
    if nargin == 2
        chanlist = 'channels'; % default to clustering the whole STUDY 
    end   
    customRes = [];
    Ncond = length(STUDY.condition);
    if Ncond == 0
        Ncond = 1;
    end

    g = finputcheck(varargin, { 'erp'         'string'  { 'on','off' }     'off';
                                'interp'      'string'  { 'on','off' }     'off';
                                'ersp'        'string'  { 'on','off' }     'off';
                                'recompute'   'string'  { 'on','off' }     'off';
                                'spec'        'string'  { 'on','off' }     'off';
                                'erpim'       'string'  { 'on','off' }     'off';
                                'scalp'       'string'  { 'on','off' }     'off';
                                'allcomps'    'string'  { 'on','off' }     'off';
                                'itc'         'string'  { 'on','off' }     'off';
                                'savetrials'  'string'  { 'on'       }     'on'; % change for EEGLAB 15
                                'rmicacomps'  'string'  { 'on','off','processica' }     'off';
                                'cell'        'integer' []                 [];
                                'design'      'integer' []                 STUDY.currentdesign;
                                'rmclust'     'integer' []                 [];
                                'rmbase'      'integer' []                 []; % deprecated, for backward compatibility purposes, not documented
                                'specparams'        'cell'    {}                 {};
                                'erpparams'         'cell'    {}                 {};
                                'customfunc'  {'function_handle' 'integer' } { { } {} }     [];
                                'customparams'      'cell'    {}                 {};
                                'customfileext'     'string'  []                 '';
                                'customclusters'    'integer' []                 [];
                                'erpimparams'       'cell'    {}                 {};
                                'erspparams'        'cell'    {}                 {}}, 'std_precomp');
    if isstr(g), error(g); end
    if ~isempty(g.rmbase), g.erpparams = { g.erpparams{:} 'rmbase' g.rmbase }; end
    if ~isempty(g.customfileext), error('customfileext option has been removed from this function. Let us know if this is something you need.'); end
    
    % union of all channel structures
    % -------------------------------
    computewhat = 'channels';
    if isstr(chanlist)
        if strcmpi(chanlist, 'channels')
            chanlist = [];
        else % components
            computewhat = 'components';
            if strcmpi(g.allcomps, 'on')
                chanlist = {};
                for index = 1:length(STUDY.datasetinfo)
                    chanlist = { chanlist{:} [1:size(ALLEEG(STUDY.datasetinfo(index).index).icaweights,1)] };
                end
            else
                chanlist = { STUDY.datasetinfo.comps };
            end
        end
    end
    if isempty(chanlist)
        alllocs = eeg_mergelocs(ALLEEG.chanlocs);
        chanlist = { alllocs.labels };
    elseif ~isnumeric(chanlist{1})
        alllocs = eeg_mergelocs(ALLEEG.chanlocs);
        [tmp c1 c2] = intersect_bc( lower({ alllocs.labels }), lower(chanlist));
        [tmp c2] = sort(c2);
        alllocs = alllocs(c1(c2));
    end
    
    % test if interp and reconstruct channel list
    % -------------------------------------------
    if strcmpi(computewhat, 'channels')
        if strcmpi(g.interp, 'on')
            STUDY.changrp = [];
            STUDY = std_changroup(STUDY, ALLEEG, chanlist, 'interp');
            g.interplocs = alllocs;
        else
            STUDY.changrp = [];
            STUDY = std_changroup(STUDY, ALLEEG, chanlist);
            g.interplocs = struct([]);
        end
    end
    
    % components or channels
    % ----------------------
    if strcmpi(computewhat, 'channels')
         curstruct = STUDY.changrp;
    else curstruct = STUDY.cluster;
    end
        
    % compute custom measure
    % ----------------------
    if ~isempty(g.customfunc)
        allSubjects = { STUDY.datasetinfo.subject };
        uniqueSubjects = unique(allSubjects);
        for iSubj = 1:length(uniqueSubjects)
            inds = strmatch( uniqueSubjects{iSubj}, allSubjects, 'exact');
            filepath = STUDY.datasetinfo(inds(1)).filepath;
            filebase = fullfile(filepath, uniqueSubjects{iSubj});
            trialinfo = std_combtrialinfo(STUDY.datasetinfo, inds);
            
            addopts = { 'savetrials' g.savetrials 'recompute' g.recompute 'fileout' filebase 'trialinfo' trialinfo };
            if strcmpi(computewhat, 'channels')
                [tmpchanlist opts] = getchansandopts(STUDY, ALLEEG, chanlist, inds, g);
                tmpData = feval(g.customfunc, ALLEEG(inds),  'channels', tmpchanlist, opts{:}, addopts{:}, g.customparams{:});
            else
                if length(inds)>1 && ~isequal(chanlist{inds})
                    error(['ICA decompositions must be identical if' 10 'several datasets are concatenated' 10 'for a given subject' ]);
                end
                tmpData = feval(g.customfunc, ALLEEG(inds), 'components', chanlist{inds(1)}, opts{:}, addopts{:}, g.customparams{:});
            end
            customRes{iSubj} = resTmp;
        end
    end

    % compute ERPs
    % ------------
    if strcmpi(g.erp, 'on')
        
        % check dataset consistency
        % -------------------------
        allPnts = [ALLEEG(:).pnts];
        if iscell(allPnts), allPnts = [ allPnts{:} ]; end
        if length(unique(allPnts)) > 1
            error([ 'Cannot compute ERPs because datasets' 10 'do not have the same number of data points' ])
        end

        allSubjects = { STUDY.datasetinfo.subject };
        uniqueSubjects = unique(allSubjects);
        for iSubj = 1:length(uniqueSubjects)
            inds = strmatch( uniqueSubjects{iSubj}, allSubjects, 'exact');
            filepath = STUDY.datasetinfo(inds(1)).filepath;
            filebase = fullfile(filepath, uniqueSubjects{iSubj});
            trialinfo = std_combtrialinfo(STUDY.datasetinfo, inds, [ALLEEG.trials]);
     
            addopts = { 'savetrials' g.savetrials 'recompute' g.recompute 'fileout' filebase 'trialinfo' trialinfo };
            if strcmpi(computewhat, 'channels')
                [tmpchanlist opts] = getchansandopts(STUDY, ALLEEG, chanlist, inds, g);
                std_erp(ALLEEG(inds), 'channels', tmpchanlist, opts{:}, addopts{:}, g.erpparams{:});
            else
                if length(inds)>1 && ~isequal(chanlist{inds})
                    error(['ICA decompositions must be identical if' 10 'several datasets are concatenated' 10 'for a given subject' ]);
                end
                std_erp(ALLEEG(inds), 'components', chanlist{inds(1)}, addopts{:}, g.erpparams{:});
            end
        end
        if isfield(curstruct, 'erpdata')
            curstruct = rmfield(curstruct, 'erpdata');
            curstruct = rmfield(curstruct, 'erptimes');
        end
    end
    
    % compute spectrum
    % ----------------
    if strcmpi(g.spec, 'on')

        allSubjects = { STUDY.datasetinfo.subject };
        uniqueSubjects = unique(allSubjects);
        for iSubj = 1:length(uniqueSubjects)
            inds = strmatch( uniqueSubjects{iSubj}, allSubjects, 'exact');
            filepath = STUDY.datasetinfo(inds(1)).filepath;
            filebase = fullfile(filepath, uniqueSubjects{iSubj});
            trialinfo = std_combtrialinfo(STUDY.datasetinfo, inds, [ALLEEG.trials]);

            addopts = { 'savetrials', g.savetrials, 'recompute', g.recompute, 'fileout', filebase, 'trialinfo', trialinfo };
            if strcmpi(computewhat, 'channels')
                [tmpchanlist opts] = getchansandopts(STUDY, ALLEEG, chanlist, inds, g);
                std_spec(ALLEEG(inds), 'channels', tmpchanlist, opts{:}, addopts{:}, g.specparams{:});
            else
                if length(inds)>1 && ~isequal(chanlist{inds})
                    error(['ICA decompositions must be identical if' 10 'several datasets are concatenated' 10 'for a given subject' ]);
                end
                std_spec(ALLEEG(inds), 'components', chanlist{inds(1)}, addopts{:}, g.specparams{:});
            end
        end
        if isfield(curstruct, 'specdata')
            curstruct = rmfield(curstruct, 'specdata');
            curstruct = rmfield(curstruct, 'specfreqs');
        end
    end

    % compute spectrum
    % ----------------
    if strcmpi(g.erpim, 'on')
        
        % check dataset consistency
        % -------------------------
        allPnts = [ALLEEG(:).pnts];
        if iscell(allPnts), allPnts = [ allPnts{:} ]; end
        if length(unique(allPnts)) > 1
            error([ 'Cannot compute ERPs because datasets' 10 'do not have the same number of data points' ])
        end

        if isempty(g.erpimparams), 
            tmpparams = {};
        elseif iscell(g.erpimparams), 
            tmpparams = g.erpimparams; 
        else
            tmpparams      = fieldnames(g.erpimparams); tmpparams = tmpparams';
            tmpparams(2,:) = struct2cell(g.erpimparams);
        end
        
        % loop accross subjects
        allSubjects = { STUDY.datasetinfo.subject };
        uniqueSubjects = unique(allSubjects);
        for iSubj = 1:length(uniqueSubjects)
            inds = strmatch( uniqueSubjects{iSubj}, allSubjects, 'exact');
            filepath = STUDY.datasetinfo(inds(1)).filepath;
            filebase = fullfile(filepath, uniqueSubjects{iSubj});
            trialinfo = std_combtrialinfo(STUDY.datasetinfo, inds);
            
            addopts = { 'savetrials' g.savetrials 'recompute' g.recompute 'fileout' filebase 'trialinfo' trialinfo tmpparams{:} };
            if strcmpi(computewhat, 'channels')
                [tmpchanlist opts] = getchansandopts(STUDY, ALLEEG, chanlist, inds, g);
                std_erpimage(ALLEEG(inds), 'channels', tmpchanlist, opts{:}, addopts{:});
            else
                if length(inds)>1 && ~isequal(chanlist{inds})
                    error(['ICA decompositions must be identical if' 10 'several datasets are concatenated' 10 'for a given subject' ]);
                end
                std_erpimage(ALLEEG(inds), 'components', chanlist{inds(1)}, addopts{:});
            end
        end
        
       if isfield(curstruct, 'erpimdata')
            curstruct = rmfield(curstruct, 'erpimdata');
            curstruct = rmfield(curstruct, 'erpimtimes');
            curstruct = rmfield(curstruct, 'erpimtrials');
            curstruct = rmfield(curstruct, 'erpimevents');
        end
    end
    
    % compute component scalp maps
    % ----------------------------
    if strcmpi(g.scalp, 'on') && ~strcmpi(computewhat, 'channels')
        for index = 1:length(STUDY.datasetinfo)
            
            % find duplicate
            % --------------
            found = [];
            ind1 = STUDY.datasetinfo(index).index;
            inds = strmatch(STUDY.datasetinfo(index).subject, { STUDY.datasetinfo(1:index-1).subject });
            for index2 = 1:length(inds)
                ind2 = STUDY.datasetinfo(inds(index2)).index;
                if isequal(ALLEEG(ind1).icawinv, ALLEEG(ind2).icawinv)
                    found = ind2;
                end
            end
            
            % make link if duplicate
            % ----------------------
            if ~isempty(g.cell)
                desset = STUDY.design(g.design).cell(g.cell);
                [path,tmp] = fileparts(desset.filebase);
            else path = ALLEEG(index).filepath;
            end
            
            fprintf('Computing/checking topo file for dataset %d\n', ind1);
            if ~isempty(found)
                clear tmp;
                tmpfile1 = fullfile( path, [ ALLEEG(index).filename(1:end-3) 'icatopo' ]); 
                tmp.file = fullfile( ALLEEG(found).filepath, [ ALLEEG(found).filename(1:end-3) 'icatopo' ]); 
                std_savedat(tmpfile1, tmp);
            else
                std_topo(ALLEEG(index), chanlist{index}, 'none', 'recompute', g.recompute,'fileout',path);
            end
        end
        if isfield(curstruct, 'topo')
            curstruct = rmfield(curstruct, 'topo');
            curstruct = rmfield(curstruct, 'topox');
            curstruct = rmfield(curstruct, 'topoy');
            curstruct = rmfield(curstruct, 'topoall');
            curstruct = rmfield(curstruct, 'topopol');
        end
    end
    
    % compute ERSP and ITC
    % --------------------
    if strcmpi(g.ersp, 'on') || strcmpi(g.itc, 'on')
        
        % check dataset consistency
        allPnts = [ALLEEG(:).pnts];
        if iscell(allPnts), allPnts = [ allPnts{:} ]; end
        if length(unique(allPnts)) > 1
            error([ 'Cannot compute ERPs because datasets' 10 'do not have the same number of data points' ])
        end
        
        % options
        if strcmpi(g.ersp, 'on') & strcmpi(g.itc, 'on'), type = 'both';
        elseif strcmpi(g.ersp, 'on')                   , type = 'ersp';
        else                                             type = 'itc';
        end
        if isempty(g.erspparams), 
            tmpparams = {};
        elseif iscell(g.erspparams), 
            tmpparams = g.erspparams; 
        else
            tmpparams      = fieldnames(g.erspparams); tmpparams = tmpparams';
            tmpparams(2,:) = struct2cell(g.erspparams);
        end
        
        % loop accross subjects
        allSubjects = { STUDY.datasetinfo.subject };
        uniqueSubjects = unique(allSubjects);
        for iSubj = 1:length(uniqueSubjects)
            inds = strmatch( uniqueSubjects{iSubj}, allSubjects, 'exact');
            filepath = STUDY.datasetinfo(inds(1)).filepath;
            filebase = fullfile(filepath, uniqueSubjects{iSubj});
            trialinfo = std_combtrialinfo(STUDY.datasetinfo, inds);
            
            addopts = { 'savetrials' g.savetrials 'recompute' g.recompute 'fileout' filebase 'trialinfo' trialinfo tmpparams{:} };
            if strcmpi(computewhat, 'channels')
                [tmpchanlist opts] = getchansandopts(STUDY, ALLEEG, chanlist, inds, g);
                std_ersp(ALLEEG(inds), 'channels', tmpchanlist, opts{:}, addopts{:});
            else
                if length(inds)>1 && ~isequal(chanlist{inds})
                    error(['ICA decompositions must be identical if' 10 'several datasets are concatenated' 10 'for a given subject' ]);
                end
                std_ersp(ALLEEG(inds), 'components', chanlist{inds(1)}, addopts{:});
            end
        end
        
        % remove saved data if any
        if isfield(curstruct, 'erspdata')
            curstruct = rmfield(curstruct, 'erspdata');
            curstruct = rmfield(curstruct, 'ersptimes');
            curstruct = rmfield(curstruct, 'erspfreqs');
        end
        if isfield(curstruct, 'itcdata')
            curstruct = rmfield(curstruct, 'itcdata');
            curstruct = rmfield(curstruct, 'itctimes');
            curstruct = rmfield(curstruct, 'itcfreqs');
        end
        
    end

    % empty cache
    % -----------
    STUDY.cache = [];
    
    % components or channels
    % ----------------------
    if strcmpi(computewhat, 'channels')
         STUDY.changrp = curstruct;
    else STUDY.cluster = curstruct;
    end
    
    return;
        
    % find components in cluster for specific dataset
    % -----------------------------------------------
    function rmcomps = getclustcomps(STUDY, rmclust, settmpind)
    
        rmcomps   = cell(1,length(settmpind));
        for idat = 1:length(settmpind) % scan dataset for which to find component clusters
            for rmi = 1:length(rmclust) % scan clusters
                comps = STUDY.cluster(rmclust(rmi)).comps;
                sets  = STUDY.cluster(rmclust(rmi)).sets;
                indmatch = find(sets(:) == settmpind(idat));
                indmatch = ceil(indmatch/size(sets,1)); % get the column number
                rmcomps{idat} = [rmcomps{idat} comps(indmatch(:)') ];
            end
            rmcomps{idat} = sort(rmcomps{idat});
        end
        
    % make option array and channel list (which depend on interp) for any type of measure
    % ----------------------------------------------------------------------
    function [tmpchanlist, opts] = getchansandopts(STUDY, ALLEEG, chanlist, idat, g)
        
        opts = { };

        if ~isempty(g.rmclust) || strcmpi(g.rmicacomps, 'on') || strcmpi(g.rmicacomps, 'processica')
            rmcomps = cell(1,length(idat));
            if ~isempty(g.rmclust)
                rmcomps = getclustcomps(STUDY, g.rmclust, idat);
            end
            if strcmpi(g.rmicacomps, 'on')
                for ind = 1:length(idat)
                    rmcomps{ind} = union_bc(rmcomps{ind}, find(ALLEEG(idat(ind)).reject.gcompreject));
                end
            elseif strcmpi(g.rmicacomps, 'processica')
                for ind = 1:length(idat)
                    rmcomps{ind} = union_bc(rmcomps{ind}, find(~ALLEEG(idat(ind)).reject.gcompreject));
                end
            end
            opts = { opts{:} 'rmcomps' rmcomps };
        end
        if strcmpi(g.interp, 'on')
            tmpchanlist = chanlist;
            allocs = eeg_mergelocs(ALLEEG.chanlocs);
            [tmp1 tmp2 neworder] = intersect_bc( {allocs.labels}, chanlist);
            [tmp1 ordertmp2] = sort(tmp2);
            neworder = neworder(ordertmp2);
            opts = { opts{:} 'interp' allocs(neworder) };
        else
            newchanlist = [];
            tmpchanlocs = ALLEEG(idat(1)).chanlocs;
            chanlocs = { tmpchanlocs.labels };
            for i=1:length(chanlist)
                newchanlist = [ newchanlist strmatch(chanlist{i}, chanlocs, 'exact') ];
            end
            tmpchanlocs =  ALLEEG(idat(1)).chanlocs;
            tmpchanlist = { tmpchanlocs(newchanlist).labels };
        end
        
    % compute full file names
    % -----------------------
    function res = computeFullFileName(filePaths, fileNames)
        for index = 1:length(fileNames)
            res{index} = fullfile(filePaths{index}, fileNames{index});
        end
