%% Import data

[rho_m,Z] = transform(importfileNumTable("gomogen muscle pulse.txt", [6, Inf]));

rho_h = rho_m(1);

%% Reconstruction Model

fmdl = mk_library_model('adult_male_16el');

[fmdl.stimulation,fmdl.meas_select]= mk_stim_patterns(16,1,[0,1],[0,1],{'rotate_meas'},1);
opt.imgsz = [32 32];
opt.square_pixels = true;
opt.noise_figure = 0.5;

figure();
fmdl.nodes = fmdl.nodes / Perimeter(fmdl) * 1;
H = range(fmdl.nodes(:,3));

show_fem(fmdl);

%% Absolute Inverse solution

amdl = mk_common_model('b2c2',32); %generic mdl
amdl.solve = @inv_solve_gn; %Default Gauss Newton solvers
amdl.fwd_model = fmdl;
amdl.reconst_type = 'absolute';
amdl.jacobian_bkgnd.value= 1/rho_h;

amdl.inv_solve_gn.max_iterations = 10 ; %Number of iterations
amdl.inv_solve_gn.stop_tolerance = 1e-8;

%cc.cb_shrink_move = [0.5,0.8,0.00];

amdl.RtR_prior=@prior_noser;

hp = 2;

amdl.hyperparameter.value = hp;
%%
aimg = inv_solve(amdl, Z');
%aimg_inspdiast = inv_solve(amdl, vv(:,i_inspdiast));
%aimg_expsyst = inv_solve(amdl, vv(:,i_expsyst));
%img.calc_colours = cc;

%%

figure()
show_slices(aimg,[inf,inf,.5*H]);
eidors_colourbar(aimg);
title("Absolute Images");

dimg = aimg;
dimg.elem_data = dimg.elem_data(:,2:end)-dimg.elem_data(:,1)
figure()
show_slices(dimg,[inf,inf,.5*H]);
eidors_colourbar(dimg);
title("Subtract absolute Img_n - Img_1");

%%
figure()
histogram(aimg.elem_data(:,1),'FaceAlpha',.2); hold on;
for i = 2:size(aimg.elem_data,2)
    histogram(aimg.elem_data(:,i),'FaceAlpha',.2);
end

mean_sigma_est = mean(aimg.elem_data)';
sigma = 1./rho_m;

figure();
plot(rho_m,sigma,'-o','LineWidth',1.1);
ylabel("\sigma_{mdl}, S/m");
xlabel("\rho_{mdl}, \Omega\cdot m");
grid on; grid minor;
yyaxis right
plot(rho_m,mean_sigma_est,'-o','LineWidth',1.1);
ylabel("\sigma_{est}, S/m");

%% 

figure();
plot([aimg.meas_err(:,1),Z(1,:)']);

