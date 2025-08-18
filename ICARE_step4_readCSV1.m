%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% step4_readCSV_and_pad_save_mat_multiCenter.m
% 多中心模式：遍历多个医院中心，读取 CSV → 填充 → 保存为 .mat
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

clc; clear; close all;

% ———— 1. 定义项目根目录 & 所有中心名称 ————
projRoot = '/Users/yinziyuan/Desktop/PacMap Project/ICARE_GUI_modifications-main';
centers = {'UTW', 'MGH', 'BWH'};  % 可按需添加中心名

% ———— 2. 采样率 ————
Fs = 100;  % Hz

for c = 1:length(centers)
    center = centers{c};
    fprintf('🌐 正在处理中心: %s\n', center);

    % ———— 3. 设置路径 ————
    eegDir = fullfile(projRoot, 'eeg', center);
    csvDir = fullfile(projRoot, 'result', center);
    outDir = fullfile(projRoot, 'GUI_results', center, 'model_prediction');
    if ~exist(outDir, 'dir')
        mkdir(outDir);
    end

    % ———— 4. 遍历 EEG 文件 ————
    eegFiles = dir(fullfile(eegDir, '*.mat'));
    nFiles = numel(eegFiles);

    if nFiles == 0
        fprintf('⚠️  中心 %s 没有 EEG 文件，跳过\n\n', center);
        continue;
    end

    for i = 1:nFiles
        [~, name] = fileparts(eegFiles(i).name);

        % —— 读取 EEG 时长 ——
        info = whos('-file', fullfile(eegDir, eegFiles(i).name));
        if ismember('data', {info.name})
            D = load(fullfile(eegDir, eegFiles(i).name), 'data');
            M = size(D.data, 2);
        else
            X = load(fullfile(eegDir, eegFiles(i).name), 'x');
            M = size(X.x.data, 2);
        end
        mm = ceil(M / (2 * Fs));  % 2秒为一段，计算总段数

        % —— 查找对应 CSV ——  
        csvPath = fullfile(csvDir, [name '_score.csv']);
        if ~isfile(csvPath)
            warning('❌ 缺失 CSV 文件: %s，跳过', csvPath);
            continue;
        end

        % —— 读取模型输出 CSV ——  
        tbl = readtable(csvPath);
        Ycsv = table2array(tbl);

        % —— 前后填充 ——  
        Y = [repmat(Ycsv(1,:), 2, 1); Ycsv];
        nn = size(Y,1);

        if nn > mm
            warning('⚠️ 窗口数 nn=%d 超过 mm=%d: 截断为 mm', nn, mm);
            Y = Y(1:mm,:);
        elseif nn < mm
            Y = [Y; repmat(Y(end,:), mm - nn, 1)];
        end

        % —— 保存为 .mat ——  
        Y_model = Y; %#ok<NASGU>
        save(fullfile(outDir, [name '_score.mat']), 'Y_model', '-v7.3');

        fprintf('✅ (%2d/%2d) [%s] %s → %d rows → saved\n', i, nFiles, center, name, size(Y,1));
    end

    fprintf('✅ 中心 %s 处理完毕，共 %d 个文件\n\n', center, nFiles);
end