# instant-ngp-docker

It provides docker images and simple usage examples for using instant-ngp.

As written in [execute.ipynb](execute.ipynb), users can proceed with instant-ngp rendering by uploading the collected data to `/content`

[execute.ipynb](execute.ipynb) supports two data formats.
> `.mp4`: Video recorded in mp4 format. By default, only 150 frames are used.
> > Change the variable `get_frames` as you want.
> 
> `.zip`: Compress multiple photos taken into a zip file. By default, all files with extension jpg/jpeg/png are used for training.
> > If you are using a different format file, change the variable `consider_EXT` as you want.

