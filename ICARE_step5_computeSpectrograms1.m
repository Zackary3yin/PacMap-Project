%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% step5_compute_spectrograms_multiCenter.m
% 多中心模式：为每个中心计算多谱线谱图并保存
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

clc; clear; close all;

% ———— 1. 定义根目录 & 中心列表 ————
projRoot = '/Users/yinziyuan/Desktop/PacMap Project/ICARE_GUI_modifications-main';
centers = {'UTW', 'MGH', 'BWH'};  % 根据实际情况添加中心

% 添加 qEEG 工具箱路径
qEEGtool = fullfile(projRoot, 'Tools', 'qEEG');
addpath(genpath(qEEGtool));

% ———— 2. 设置谱图参数 ————
Fs = 100;
params.movingwin = [4, 2];        % 窗长 4s，步长 2s
params.tapers    = [2, 3];        % Taper 参数
params.fpass     = [0.5, 20];     % 频段
params.Fs        = Fs;

% ———— 3. 遍历每个中心 ————
for c = 1:length(centers)
    center = centers{c};
    fprintf('🌐 正在处理中心: %s\n', center);

    % 设置路径
    dataDir = fullfile(projRoot, 'eeg', center);
    outDir  = fullfile(projRoot, 'GUI_results', center, 'Spectrograms1');
    if ~exist(outDir, 'dir')
        mkdir(outDir);
    end

    % 获取 EEG 文件列表
    eegFiles = dir(fullfile(dataDir, '*.mat'));
    if isempty(eegFiles)
        fprintf('⚠️  中心 %s 无 EEG 文件，跳过\n\n', center);
        continue;
    end

    % 遍历每个 EEG 文件
    for i = 1:numel(eegFiles)
        [~, name] = fileparts(eegFiles(i).name);

        % 加载 EEG 数据
        S = load(fullfile(dataDir, eegFiles(i).name));
        if isfield(S, 'data')
            raw = S.data;
        elseif isfield(S, 'x')
            raw = S.x.data;
        else
            warning('❌ 无法识别 EEG 文件变量: %s，跳过', name);
            continue;
        end
        raw(isnan(raw)) = 0;

        % 取前19通道并转为双极导联
        eeg_bi = fcn_Bipolar(raw(1:19, :));

        % 计算谱图
        [Sdata, stimes, sfreqs] = fcn_computeSpec(eeg_bi, params);
        stimes = round(stimes);

        % 保存谱图结果
        specFile = fullfile(outDir, [name '_spect.mat']);
        save(specFile, 'Sdata', 'stimes', 'sfreqs', 'params', '-v7.3');
        fprintf('✅ (%2d/%2d) [%s] 计算完成: %s\n', i, numel(eegFiles), center, name);
    end

    fprintf('✅ 中心 %s 处理完毕，共处理 %d 个文件\n\n', center, numel(eegFiles));
end