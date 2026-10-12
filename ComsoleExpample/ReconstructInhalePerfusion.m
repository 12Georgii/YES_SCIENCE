%% Read data
frame_base = importComsol("Данные резы.xlsx","изменение проводимости легких", [5,20]);
frame_pulse = importComsol("Данные резы.xlsx","изменение проводимости легких", [26,41]);

%% Reconstruction model
fmdl = mk_library_model('adult_male_32el');
fmdl.electrode(1:2:end)=[];% skip each second
fmdl.electrode = circshift(fmdl.electrode,1);

[fmdl.stimulation,fmdl.meas_select]= mk_stim_patterns(16,1,[0,1],[0,1],{'no_rotate_meas'},1);
opt.imgsz = [32 32];
opt.square_pixels = true;
opt.noise_figure = 0.5;
imdl= mk_GREIT_model(mk_image(fmdl,1/50), 0.20, [], opt);

%% Reconstruct images

vh = DiffVoltage(frame_base.V); % reference level

vv =  DiffVoltage(frame_pulse.V);

imgr = inv_solve(imdl, vh, vv); % reconstructed image
%% Show image

imgr.elem_data = -imgr.elem_data;
figure();
show_fem(imgr,[1,1.012]);

%%
figure();
histogram(imgr.elem_data)
xlabel("\Delta\rho, Ohm");ylabel("count");
title("\Delta\rho = 1.2 Ohm*m");