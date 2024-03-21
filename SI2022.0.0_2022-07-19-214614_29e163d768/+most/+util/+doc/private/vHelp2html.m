function [outStr, found] = vHelp2html(topic,pagetitle,helpCommandOption)
%HELP2HTML Convert M-help to an HTML form.
% 
%   This file is a helper function used by the HelpPopup Java component.  
%   It is unsupported and may change at any time without notice.

%   Copyright 2007-2008 The MathWorks, Inc.
if nargin == 0
    topic = '';
end
if nargin < 2
    pagetitle = '';
end
if nargin < 3
    helpCommandOption = '-helpwin';
end
dom = com.mathworks.xml.XMLUtils.createDocument('help-info');
dom.getDomConfig.setParameter('cdata-sections',true);

[helpNode, helpstr, fcnName, found] = vHelp2xml(dom, topic, pagetitle, helpCommandOption);

afterHelp = '';
if found
    % Handle characters that are special to HTML 
    helpstr = fixsymbols(helpstr);

    % Extract the see also and overloaded links from the help text.
    % Since these are already formatted as links, we'll keep them 
    % intact rather than parsing them into XML and transforming
    % them back to HTML.
    helpParts = matlab.internal.language.introspective.helpParts(helpstr);
    afterHelp = moveToAfterHelp(afterHelp, helpParts, {'seeAlso', 'note', 'overloaded', 'demo'});
    
    helpstr = deblank(helpParts.getFullHelpText);
    shortName = regexp(fcnName, '(?<=\W)\w*$', 'match', 'once');
    helpstr = helpUtils.highlightHelp(helpstr, fcnName, shortName, '<span class="helptopic">', '</span>');
elseif strcmp(helpCommandOption, '-doc')
    outStr = '';
    return;
end

helpdir = fileparts(mfilename('fullpath'));
helpdir = ['file:///' strrep(helpdir,'\','/')];
addTextNode(dom,dom.getDocumentElement,'helptools-dir',helpdir);

if found
    addAttribute(dom,helpNode,'helpfound','true');
else
    addAttribute(dom,helpNode,'helpfound','false');
    % It's easier to escape the quotes in M than in XSL, so do it here.
    addTextNode(dom,helpNode,'escaped-topic',strrep(fcnName,'''',''''''));
end

% Prepend warning about empty docroot, if we've been called by doc.m
if strcmp(helpCommandOption, '-doc') && ~helpUtils.isDocInstalled
    addAttribute(dom,dom.getDocumentElement,'doc-installed','false');
    warningGif = sprintf('file:///%s',strrep(fullfile(matlabroot,'toolbox','matlab','icons','warning.gif'),'\','/'));
    addTextNode(dom,dom.getDocumentElement,'warning-image',warningGif);
    helperrPage = sprintf('file:///%s',strrep(fullfile(matlabroot,'toolbox','local','helperr.html'),'\','/'));
    addTextNode(dom,dom.getDocumentElement,'error-page',helperrPage);
end

addTextNode(dom,dom.getDocumentElement,'default-topics-text',getString(message('MATLAB:helpwin:sprintf_DefaultTopics')));
addTextNode(dom,dom.getDocumentElement,'help-command-option',helpCommandOption(2:end));
xslfile = fullfile(fileparts(mfilename('fullpath')),'helpwin.xsl');
outStr = xslt(dom,xslfile,'-tostring');

% Use HTML entities for non-ASCII characters
helpstr = regexprep(helpstr,'[^\x0-\x7f]','&#x${dec2hex($0)};');
afterHelp = regexprep(afterHelp,'[^\x0-\x7f]','&#x${dec2hex($0)};');
outStr = regexprep(outStr,'\s*(<!--\s*helptext\s*-->)', sprintf('$1%s',regexptranslate('escape',helpstr)));
outStr = regexprep(outStr,'\s*(<!--\s*after help\s*-->)', sprintf('$1%s',regexptranslate('escape',afterHelp)));

%==========================================================================
function afterHelp = moveToAfterHelp(afterHelp, helpParts, parts)
for i = 1:length(parts)
    part = helpParts.getPart(parts{i});
    if ~isempty(part)
        title = part.getTitle;
        if title(end) == ':'
            title = title(1:end-1);
        end
        afterHelp = sprintf('%s<!--%s-->', afterHelp, parts{i});
        afterHelp = sprintf('%s<div class="footerlinktitle">%s</div>', afterHelp, title);
        afterHelp = sprintf('%s<div class="footerlink">%s</div>', afterHelp, part.getText);
        part.clearPart;
    end
end

%==========================================================================
function addTextNode(dom,parent,name,text)
child = dom.createElement(name);
child.appendChild(dom.createTextNode(text));
parent.appendChild(child);

%==========================================================================
function addAttribute(dom,elt,name,text)
att = dom.createAttribute(name);
att.appendChild(dom.createTextNode(text));
elt.getAttributes.setNamedItem(att);




% ----------------------------------------------------------------------------
% Copyright (C) 2022 Vidrio Technologies, LLC
% 
% ScanImage (R) 2022 is software to be used under the purchased terms
% Code may be modified, but not redistributed without the permission
% of Vidrio Technologies, LLC
% 
% VIDRIO TECHNOLOGIES, LLC MAKES NO WARRANTIES, EXPRESS OR IMPLIED, WITH
% RESPECT TO THIS PRODUCT, AND EXPRESSLY DISCLAIMS ANY WARRANTY OF
% MERCHANTABILITY OR FITNESS FOR A PARTICULAR PURPOSE.
% IN NO CASE SHALL VIDRIO TECHNOLOGIES, LLC BE LIABLE TO ANYONE FOR ANY
% CONSEQUENTIAL OR INCIDENTAL DAMAGES, EXPRESS OR IMPLIED, OR UPON ANY OTHER
% BASIS OF LIABILITY WHATSOEVER, EVEN IF THE LOSS OR DAMAGE IS CAUSED BY
% VIDRIO TECHNOLOGIES, LLC'S OWN NEGLIGENCE OR FAULT.
% CONSEQUENTLY, VIDRIO TECHNOLOGIES, LLC SHALL HAVE NO LIABILITY FOR ANY
% PERSONAL INJURY, PROPERTY DAMAGE OR OTHER LOSS BASED ON THE USE OF THE
% PRODUCT IN COMBINATION WITH OR INTEGRATED INTO ANY OTHER INSTRUMENT OR
% DEVICE.  HOWEVER, IF VIDRIO TECHNOLOGIES, LLC IS HELD LIABLE, WHETHER
% DIRECTLY OR INDIRECTLY, FOR ANY LOSS OR DAMAGE ARISING, REGARDLESS OF CAUSE
% OR ORIGIN, VIDRIO TECHNOLOGIES, LLC's MAXIMUM LIABILITY SHALL NOT IN ANY
% CASE EXCEED THE PURCHASE PRICE OF THE PRODUCT WHICH SHALL BE THE COMPLETE
% AND EXCLUSIVE REMEDY AGAINST VIDRIO TECHNOLOGIES, LLC.
% ----------------------------------------------------------------------------
