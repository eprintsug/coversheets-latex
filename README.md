# coversheets-latex
##Coversheets in the traditional LaTeX style

This Coversheets plugin allows to use LaTeX (https://www.latex-project.org) to create a 
coversheet. It is a modification of the existing Coversheets plugin 
(http://bazaar.eprints.org/350/).

The following modifications were made:

- Enhanced management of selection criteria for a cover
- Generation of a coversheet was removed from the indexer process. This avoids major 
drawbacks: Firstly the user experience is inconsistent – the first person to download 
the item will not see the coversheet as the coversheet will not be applied until the 
indexer task has run which could be much later. Secondly, for a large repositories 
a change to a coversheet can result in huge numbers of tasks being placed on the indexer 
queue which will impact the performance of the site in general but more importantly 
will seriously disrupt the indexing of items for the search function.
The trigger for covering a PDF will be moved to the point at which an item moves from the 
inbox to the review buffer (or to the Live Archive).
- The template is a LaTeX template with embedded tags. This allows mathematical 
typesetting and dynamical embedding of images, e.g. Creative Commons license batches
- A script allows for bulk covering of items
- An editor/administrator is provided with an utility to regenerate the cover for a single 
  item.
- A live item will be re-covered if a non-volatile field is changed. For other cases (e.g.
change of the template or change of volatile fields), the bulk covering tool or the 
utility to regenerate the cover for a single item can be used.

Developed by Peter West on behalf of University of Zurich, Switzerland
who have contributed this development to the E-Prints Community.

##Remark
This functionailty is also available from some older plugins that have worked well for a number 
of more venerable EPrints repositories

- http://files.eprints.org/670/
- http://files.eprints.org/465/

Plan is to review these combine the best bits and make them available here in an 
epm-friendly structure.

##Requirements

TeX Live 2015 or newer.


##General setup

The setup procedure consists of the following steps

- Installation
- Configuration


##Installation

Copy the content of the bin and cfg directories to the respective 
{eprints_root}/archives/{yourarchive}/bin and {eprints_root}/archives/{yourarchive}/cfg 
directories.


##Configuration

