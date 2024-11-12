#include <SDL.h>
#include <SDL_image.h>
#include <SDL_ttf.h>
#include <SDL_mixer.h>
#include <iostream>
#include <stdlib.h>  
#include <crtdbg.h>   //for malloc and free
#include <set>
#include <vector>
#include "cuda_runtime.h"
#include "device_launch_parameters.h"
#include <stdio.h>
#define _CRTDBG_MAP_ALLOC
#ifdef _DEBUG
#define new new( _NORMAL_BLOCK, __FILE__, __LINE__)
#endif

SDL_Window* window;
SDL_Renderer* renderer;
bool running;
SDL_Event event;
std::set<std::string> keys;
std::set<std::string> currentKeys;
int mouseX = 0;
int mouseY = 0;
int mouseDeltaX = 0;
int mouseDeltaY = 0;
int mouseScroll = 0;
std::set<int> buttons;
std::set<int> currentButtons;
const int WIDTH = 600;
const int HEIGHT = 600;


int exponent = 4;
int variables = 5;
int mod = 5;

void debug(int line, std::string file) {
	std::cout << "Line " << line << " in file " << file << ": " << SDL_GetError() << std::endl;
}

int factorial(int n) {
	int result = 1;
	for (int i = n; i > 0; i--) {
		result *= i;
	}
	return result;
}

int multinomial(int n, std::vector<int> r) {
	int result = factorial(n);
	for (int i : r) {
		result /= factorial(i);
	}
	return result % mod;
}


std::vector<int> sequenceGenerator(int start, int end, std::vector<int>* subsequence, std::vector<int> count, int variable) {
	std::vector<int> result;
	if (variable == 1) {
		subsequence = new std::vector<int>();
		for (int i = end - start; i >= 0; i--) {
			subsequence->clear();
			for (int j = 0; j < i; j++) {
				subsequence->push_back(variable);
			}
			count.push_back(i);
			if (start + i < end) {
				std::vector<int> a = sequenceGenerator(start + i, end, subsequence, count, variable + 1);
				result.insert(result.end(), a.begin(), a.end());
			}
			else {
				int m = multinomial(end, count);
				for (int i = 0; i < m; i++) {
					result.insert(result.end(), subsequence->begin(), subsequence->end());
				}
			}
			count.pop_back();
		}
		delete subsequence;
	}
	else if (variable < variables) {
		std::vector<int>* subsubsequence = new std::vector<int>();
		for (int i = end - start; i >= 0; i--) {
			subsubsequence->clear();
			subsubsequence->insert(subsubsequence->end(), subsequence->begin(), subsequence->end());
			for (int j = 0; j < i; j++) {
				subsubsequence->push_back(variable);
			}
			count.push_back(i);
			if (i + start < end) {
				std::vector<int> a = sequenceGenerator(start + i, end, subsubsequence, count, variable + 1);
				result.insert(result.end(), a.begin(), a.end());
			}
			else {
				int m = multinomial(end, count);
				for (int i = 0; i < m; i++) {
					result.insert(result.end(), subsubsequence->begin(), subsubsequence->end());
				}
			}
			count.pop_back();
		}
		delete subsubsequence;
	}
	else if (variable == variables) {
		for (int i = end - start; i > 0; i--) {
			subsequence->push_back(variable);
		}
		count.push_back(end - start);
		int m = multinomial(end, count);
		for (int i = 0; i < m; i++) {
			result.insert(result.end(), subsequence->begin(), subsequence->end());
		}
		count.pop_back();
	}
	return result;
}

const Uint32 red = 0x01000000, green = 0x00010000, blue = 0x00000100;
const Uint32 colors[] = {
	0,
	255 * (red + blue + green),
	255 * red, 
	255 * green, 
	255 * blue, 
	255 * red + 255 * green, 
	255 * red + 255 * blue, 
	255 * green + 255 * blue,
	128 * red,
	128 * green,
	128 * blue,
	128 * (red + green),
	128 * (red + blue),
	128 * (green + blue),
	153 * (red + green) + 255 * blue,
	153 * red + 51 * green + 102 * blue,
	102 * (red + blue),
	255 * red + 128 * (green + blue)
};

int main(int argc, char* argv[]) {
	if (SDL_Init(SDL_INIT_EVERYTHING) == 0 && TTF_Init() == 0 && Mix_OpenAudio(44100, MIX_DEFAULT_FORMAT, 2, 2048) == 0) {
		//Setup
		window = SDL_CreateWindow("Weaves", SDL_WINDOWPOS_CENTERED, SDL_WINDOWPOS_CENTERED, WIDTH, HEIGHT, 0);
		if (window == NULL) {
			debug(__LINE__, __FILE__);
			return 0;
		}

		renderer = SDL_CreateRenderer(window, -1, 0);
		if (renderer == NULL) {
			debug(__LINE__, __FILE__);
			return 0;
		}
		void* txtPixels;
		int pitch;
		Uint32* pixel_ptr;

		Uint8 c;

		std::vector<int> sequence = sequenceGenerator(0, exponent, NULL, {}, 1);

		SDL_Texture* texture = SDL_CreateTexture(renderer, SDL_PIXELFORMAT_RGBA8888,
			SDL_TEXTUREACCESS_STREAMING, sequence.size(), sequence.size());
		SDL_LockTexture(texture, NULL, &txtPixels, &pitch);
		pixel_ptr = (Uint32*)txtPixels;
		for (int i = 0; i < sequence.size() * sequence.size(); i++) {
			c = 0;
			c += sequence[i % sequence.size()];
			c += sequence[i / sequence.size()];
			pixel_ptr[i] = colors[c - 2] + 255;
		}
		SDL_UnlockTexture(texture);
		SDL_RenderCopy(renderer, texture, NULL, NULL);
		SDL_RenderPresent(renderer);

		//Main loop
		running = true;
		while (running) {
			//handle events
			for (std::string i : keys) {
				currentKeys.erase(i); //make sure only newly pressed keys are in currentKeys
			}
			for (int i : buttons) {
				currentButtons.erase(i); //make sure only newly pressed buttons are in currentButtons
			}
			mouseScroll = 0;
			while (SDL_PollEvent(&event)) {
				switch (event.type) {
				case SDL_QUIT:
					running = false;
					break;
				case SDL_KEYDOWN:
					if (!keys.contains(std::string(SDL_GetKeyName(event.key.keysym.sym)))) {
						currentKeys.insert(std::string(SDL_GetKeyName(event.key.keysym.sym)));
					}
					keys.insert(std::string(SDL_GetKeyName(event.key.keysym.sym))); //add keydown to keys set
					break;
				case SDL_KEYUP:
					keys.erase(std::string(SDL_GetKeyName(event.key.keysym.sym))); //remove keyup from keys set
					break;
				case SDL_MOUSEMOTION:
					mouseX = event.motion.x;
					mouseY = event.motion.y;
					mouseDeltaX = event.motion.xrel;
					mouseDeltaY = event.motion.yrel;
					break;
				case SDL_MOUSEBUTTONDOWN:
					if (!buttons.contains(event.button.button)) {
						currentButtons.insert(event.button.button);
					}
					buttons.insert(event.button.button);
					break;
				case SDL_MOUSEBUTTONUP:
					buttons.erase(event.button.button);
					break;
				case SDL_MOUSEWHEEL:
					mouseScroll = event.wheel.y;
					break;
				}
			}
		}

		SDL_DestroyTexture(texture);

		//Clean up
		if (window) {
			SDL_DestroyWindow(window);
		}
		if (renderer) {
			SDL_DestroyRenderer(renderer);
		}
		TTF_Quit();
		Mix_Quit();
		IMG_Quit();
		SDL_Quit();
		return 0;
	}
	else {
		return 0;
	}
}