# HYPERDOC_Database_code

## HYPERDOC - HYPERspectral database of historical DOCuments and mock-ups from 400 to 1700 nm

The **HYPERDOC database** is a hyperspectral imaging dataset of historical documents and mock-ups, designed to facilitate research in material identification in the cultural heritage domain. The database contains both mock-ups of historical inks on various supports, including some artificially aged, and historical documents from the 15th to 17th centuries. Hyperspectral reflectance images were acquired in the VNIR (400-1000 nm) and SWIR (900-1700 nm) ranges and were spatially registered. Small regions of interest, referred to as 'minicubes', were extracted from the full document images, and pixel-level ground truth (GT) material annotations were performed. False-color RGB images and extensive metadata were included in both the full document and minicube captures. The database is publicly available to promote interdisciplinary collaboration and advance the use of hyperspectral imaging in the conservation field.

## Repository contents

This repository contains MATLAB and Python codes used to process and analyze the HYPERDOC database. The repository is organized into the following folders:

**(1)	Generate_GT:**
- **Generate_GT.m**: Function that generates an automatic Ground Truth from a hyperspectral cube.

**(2)	BIL to MAT:**
  
- **Process_cubes_PikaL.m**: Function that reads hyperspectral data from spectral cubes in BIL format captured with Resonon Pika L and Spectronon software, and converts it to MAT format.
- **Process_cubes_PikaNIR.m**: Function that reads hyperspectral data from spectral cubes in BIL format captured with Resonon Pika IR+ and Spectronon software, and converts it to MAT format.
    
**(3)	MAT to HDF5:**
  
- **mat_2_h5.m**: Function that converts hyperspectral cubes from MAT format to HDF5 format.
    
**(4)	Usage Notes:**
  
- **usage_notes_MATLAB.m**: Script that demonstrates how to process and analyze hyperspectral data from VNIR and SWIR hypercubes stored in HDF5 format.  
- **usage_notes_Python.ipynb**: Equivalent script for Python users.

## License

This repository is released under the [MIT License](https://github.com/anabelenlb/HYPERDOC_Database_code/blob/main/LICENSE).

## Contact

[Color Imaging Laboratory](https://colorimaginglab.ugr.es/), Department of Optics, University of Granada, Spain. colorimg@ugr.es


## Acknowledge

Please cite the following paper when publishing work relating to this code:
[include citation when paper is published]
