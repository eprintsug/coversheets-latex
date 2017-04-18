# coversheets-latex
## Coversheets in the traditional LaTeX style

This Coversheets plugin allows to use LaTeX (https://www.latex-project.org) to create a 
coversheet. It is a modification of the existing Coversheets plugin 
(http://bazaar.eprints.org/350/).

The following modifications were made:

- Enhanced management of selection criteria for a cover
- Preview of the coversheet in the admin interface
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
- The original document remains untouched. A new covered, volatile document will be 
created.


http://www.zora.uzh.ch/coversheets/15/frontfile.ltx provides a LaTeX template used in the 
Zurich Open Repository and Archive (ZORA) of University Zurich, 
http://www.zora.uzh.ch/coversheets/15/preview.pdf a preview of a record with clickable 
links. 

http://www.zora.uzh.ch/129665/1/ckm_angle.pdf provides an example that includes 
mathematical typesetting in the title and the abstract as well as a clickable 
Creative Commons license batch.

Developed by Peter West on behalf of University of Zurich, Switzerland
who have contributed this development to the E-Prints Community.

## Requirements

TeX Live 2015 or newer.


## General setup

The setup procedure consists of the following steps

- Installation
- Configuration
- Update the database
- Editing the LaTeX template


### Installation

Copy the content of the bin and cfg directories to the respective 
{eprints_root}/archives/{yourarchive}/bin and {eprints_root}/archives/{yourarchive}/cfg 
directories.


### Configuration

Edit the cfg.d/z_coversheets.pl file. Adjust the paths in

```perl
$c->{executables}->{pdflatex} = "/usr/local/texlive/2015/bin/x86_64-linux/xelatex";
$c->{executables}->{pdftk} = "/usr/bin/pdftk";
```


The cfg.d/z_coversheet_tags.pl file serves as an example for tags that can be used 
in a LaTeX template. Tags are available for title, type, abstract, url, date, citation, 
creators, DOI url, ZORA url (URL pointing to the eprint in the ZORA repository, either a 
DOI or a URL), content, and license batch (see 
[CC-licenses](https://github.com/eprintsug/CC-licenses)). Adapt it to your needs.


Restart the web server after having made changes to the configuration.

### Update the database

To add the coversheet dataset fields, update the database with `epadmin update`.


### Editing the LaTeX template 

latex_template/uzh_coversheet.ltx contains a commented LaTeX template for a coversheet 
that is used by University of Zurich. A tag is enclosed by \#\# markers: Eg. \#\#date\#\# . 

Adapt this template to your needs.


## Use

### Admin Interface

Visit the Admin webpage of your repository and choose tab System Tools, button 
Manage Coversheets.

Create a New Coversheet and upload your LaTeX template. Select the criteria, for which an
eprint must match so that a coversheet will be applied. Save using Update button.

To view the PDF preview, use the view button (with the magnifying glass) in the list of 
coversheet. Then choose the preview link.

Using the Admin webpage, tab System Tools, button Apply Coversheet, it is possible to 
reapply a coversheet to a single eprint or several eprints.


### Scripts

bin/apply_coversheets can be used to apply coversheets to all or selected items of a 
repository. Use `perldoc apply_coversheets` to print a short description of the script 
and its options.

bin/remove coversheets tries to remove a coversheet.


### Logging

Coversheet application is logged to {eprints_root}/var/coversheet.log .


## Remark
Some of the functionailty is also available from some older plugins that have worked 
well for a number of more venerable EPrints repositories

- http://files.eprints.org/670/
- http://files.eprints.org/465/

Plan is to review these combine the best bits and make them available here in an 
epm-friendly structure.
