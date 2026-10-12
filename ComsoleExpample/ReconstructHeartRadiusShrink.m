%% Read data
frames = importComsol("Данные резы.xlsx");

%% Reconstruction model
fmdl = mk_library_model('adult_male_32el');
fmdl.electrode(1:2:end)=[];% skip each second
fmdl.electrode = circshift(fmdl.electrode,1);

[fmdl.stimulation,fmdl.meas_select]= mk_stim_patterns(16,1,[0,1],[0,1],{'no_rotate_meas'},1);
opt.imgsz = [32 32];
opt.square_pixels = true;
opt.noise_figure = 0.5;
imdl= mk_GREIT_model(mk_image(fmdl,1), 0.20, [], opt);


%% Reconstruct images

vh = DiffVoltage(frames(1).V); % reference level
Nframes = length(frames);

vv= zeros(208,Nframes-1); % other frame's voltages, column by column
for i = 2:length(frames)
    vv(:,i-1) = DiffVoltage(frames(i).V);
end

imgr = inv_solve(imdl, vh, vv); % reconstructed images


%% Show images
img = imgr; % single frame image
img.calc_colours.clim = 1e3;
img.calc_colours.ref_level = 0;

figure();
for i = 1:9
    subplot(3,3,i);
    img.elem_data = -imgr.elem_data(:,i);
    show_fem(img,1);
    
    title(sprintf("dR = -%d mm",i));
end

