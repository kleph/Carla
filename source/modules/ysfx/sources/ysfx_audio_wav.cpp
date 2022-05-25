// Copyright 2021 Jean Pierre Cimalando
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//
// SPDX-License-Identifier: Apache-2.0
//

#include "ysfx_audio_wav.hpp"
#include "ysfx_utils.hpp"
#include <memory>
#include <cstring>

#if defined(__GNUC__)
#   pragma GCC diagnostic push
#   pragma GCC diagnostic ignored "-Wunused-function"
#endif

#define DR_WAV_IMPLEMENTATION
#define DRWAV_API static
#define DRWAV_PRIVATE static
#include "dr_wav.h"

#if defined(__GNUC__)
#   pragma GCC diagnostic pop
#endif

struct ysfx_wav_reader_t {
    ~ysfx_wav_reader_t() { drwav_uninit(wav.get()); }
    std::unique_ptr<drwav> wav;
    uint32_t nbuff = 0;
    std::unique_ptr<float[]> buff;
};

static bool ysfx_wav_can_handle(const char *path)
{
    return ysfx::path_has_suffix(path, "wav");
}

static ysfx_audio_reader_t *ysfx_wav_open(const char *path)
{
    std::unique_ptr<drwav> wav{new drwav};
#if !defined(_WIN32)
    drwav_bool32 initok = drwav_init_file(wav.get(), path, nullptr);
#else
    drwav_bool32 initok = drwav_init_file_w(wav.get(), ysfx::widen(path).c_str(), nullptr);
#endif
    if (!initok)
        return nullptr;
    std::unique_ptr<ysfx_wav_reader_t> reader{new ysfx_wav_reader_t};
    reader->wav = std::move(wav);
    reader->buff.reset(new float[reader->wav->channels]);
    return (ysfx_audio_reader_t *)reader.release();
}

static void ysfx_wav_close(ysfx_audio_reader_t *reader_)
{
    ysfx_wav_reader_t *reader = (ysfx_wav_reader_t *)reader_;
    delete reader;
}

static ysfx_audio_file_info_t ysfx_wav_info(ysfx_audio_reader_t *reader_)
{
    ysfx_wav_reader_t *reader = (ysfx_wav_reader_t *)reader_;
    ysfx_audio_file_info_t info;
    info.channels = reader->wav->channels;
    info.sample_rate = (ysfx_real)reader->wav->sampleRate;
    return info;
}

static uint64_t ysfx_wav_avail(ysfx_audio_reader_t *reader_)
{
    ysfx_wav_reader_t *reader = (ysfx_wav_reader_t *)reader_;
    return reader->nbuff + reader->wav->channels * (reader->wav->totalPCMFrameCount - reader->wav->readCursorInPCMFrames);
}

static void ysfx_wav_rewind(ysfx_audio_reader_t *reader_)
{
    ysfx_wav_reader_t *reader = (ysfx_wav_reader_t *)reader_;
    drwav_seek_to_pcm_frame(reader->wav.get(), 0);
    reader->nbuff = 0;
}

static uint64_t ysfx_wav_unload_buffer(ysfx_audio_reader_t *reader_, ysfx_real *samples, uint64_t count)
{
    ysfx_wav_reader_t *reader = (ysfx_wav_reader_t *)reader_;

    uint32_t nbuff = reader->nbuff;
    if (nbuff > count)
        nbuff = (uint32_t)count;

    if (nbuff == 0)
        return 0;

    const float *src = &reader->buff[reader->wav->channels - reader->nbuff];
    for (uint32_t i = 0; i < nbuff; ++i)
        samples[i] = src[i];

    reader->nbuff -= nbuff;
    return nbuff;
}

static uint64_t ysfx_wav_read(ysfx_audio_reader_t *reader_, ysfx_real *samples, uint64_t count)
{
    ysfx_wav_reader_t *reader = (ysfx_wav_reader_t *)reader_;
    uint32_t channels = reader->wav->channels;
    uint64_t readtotal = 0;

    if (count == 0)
        return readtotal;
    else {
        uint64_t copied = ysfx_wav_unload_buffer(reader_, samples, count);
        samples += copied;
        count -= copied;
        readtotal += copied;
    }

    if (count == 0)
        return readtotal;
    else {
        float *f32buf = (float *)samples;
        uint64_t readframes = drwav_read_pcm_frames_f32(reader->wav.get(), count / channels, f32buf);
        uint64_t readsamples = channels * readframes;
        // f32->f64
        for (uint64_t i = readsamples; i-- > 0; )
            samples[i] = f32buf[i];
        samples += readsamples;
        count -= readsamples;
        readtotal += readsamples;
    }

    if (count == 0)
        return readtotal;
    else if (drwav_read_pcm_frames_f32(reader->wav.get(), 1, reader->buff.get()) == 1) {
        reader->nbuff = channels;
        uint64_t copied = ysfx_wav_unload_buffer(reader_, samples, count);
        samples += copied;
        count -= copied;
        readtotal += copied;
    }

    return readtotal;
}

const ysfx_audio_format_t ysfx_audio_format_wav = {
    &ysfx_wav_can_handle,
    &ysfx_wav_open,
    &ysfx_wav_close,
    &ysfx_wav_info,
    &ysfx_wav_avail,
    &ysfx_wav_rewind,
    &ysfx_wav_read,
};
